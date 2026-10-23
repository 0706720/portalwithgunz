extends Node

signal world_ready

# ==============================================================================
# 1. EXPORTED CONFIGURATION & VARIABLES
# ==============================================================================
@export_category("Dungeon Generation Settings")
@export var room_count := 20
@export_flags_3d_physics var room_bounds_layer := 2
@export var max_attempts_per_room := 15
@export var max_backtracks := 20
@export var required_straights_after_turn := 0

@export_category("Difficulty & Scaling")
var dungeon_loop := 1
@export var difficulty_multiplier_per_loop := 1.25
@export var extra_rooms_per_loop := 3
@export var extra_arenas_per_loop := 1

@export_category("Scene References")
@export var end_room_scene: PackedScene = preload("res://assets/Rooms/Special/end_room_prefab.tscn")
@export var splitter_room_scene: PackedScene = preload("res://assets/Rooms/Special/splitter_room_prefab.tscn")
@export var start_room_scene: PackedScene = preload("res://assets/Rooms/Special/spawn_room_prefab.tscn")
@export var treasure_room_scene: PackedScene = preload("res://assets/Rooms/Special/treasure_room_prefab.tscn") 
@onready var room_container: Node3D = $"../RoomContainer"

@export_category("Arena Settings")
@export var max_main_arenas := 2
@export var branch_arena_target := 2

var main_arena_count := 0
var branch_arena_count := 0
var splitter_has_spawned := false

@export_category("Treasure Portal Settings")
@export var treasure_portal_difficulty_multiplier := 2.0
@export var treasure_reward_multiplier := 2.5

@export_category("Enemy Point-Buy System")
@export var enemy_spawn_chance := 0.7
@export var enemy_pool: Array[Dictionary] = [
	{"scene": preload("res://assets/Enemies/bat.tscn"), "cost": 4},
	{"scene": preload("res://assets/Enemies/goblin.tscn"), "cost": 5},
	{"scene": preload("res://assets/Enemies/skeleton_archer.tscn"), "cost": 10},
	#{"scene": preload("res://assets/Enemies/sorcerer.tscn"), "cost": 15},
	#{"scene": preload("res://assets/Enemies/warlock.tscn"), "cost": 15},
	#{"scene": preload("res://assets/Enemies/orc.tscn"), "cost": 20},
	#{"scene": preload("res://assets/Enemies/elite_crossbower.tscn"), "cost": 30},
	#{"scene": preload("res://assets/Enemies/elite_knight.tscn"), "cost": 35},
]

var level_generated := false
var rng := RandomNumberGenerator.new()
var all_rooms: Array[PackedScene] = []
var generated_rooms: Array[Node3D] = []
var all_branches: Array = []


# ==============================================================================
# 2. INITIALIZATION & SETUP
# ==============================================================================
func _ready() -> void:
	main_arena_count = 0
	splitter_has_spawned = false
	set_process_input(true)
	
	if multiplayer.is_server():
		rng.randomize()
		load_room_prefabs()
		
		if room_container != null and not all_rooms.is_empty():
			await generate_spawn_room_first()
			var layout_data = generate_level_aabb_layout()
			instantiate_rooms_incrementally(layout_data)
			level_generated = true
			emit_signal("world_ready")
		else:
			push_error("[ProceduralGen] Generator setup validation failed.")
	else:
		rpc_id(1, "request_world_state", multiplayer.get_unique_id())


func load_room_prefabs() -> void:
	all_rooms.clear()
	scan_folder_for_rooms("res://assets/Rooms/")


func scan_folder_for_rooms(dir_path: String) -> void:
	if "InDevelopment" in dir_path: return
	var dir := DirAccess.open(dir_path)
	if dir == null: return
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	
	while file_name != "":
		if dir.current_is_dir():
			if not file_name.begins_with(".") and file_name != "InDevelopment": 
				scan_folder_for_rooms(dir_path + file_name + "/")
		else:
			if file_name.ends_with(".tscn"):
				var full_path := dir_path + file_name
				var skip := false
				if start_room_scene and full_path == start_room_scene.resource_path: skip = true
				if end_room_scene and full_path == end_room_scene.resource_path: skip = true
				if splitter_room_scene and full_path == splitter_room_scene.resource_path: skip = true
				if treasure_room_scene and full_path == treasure_room_scene.resource_path: skip = true 
				
				if not skip:
					var scene := load(full_path) as PackedScene
					if scene and validate_prefab_structure(scene):
						all_rooms.append(scene)
		file_name = dir.get_next()
	dir.list_dir_end()


func validate_prefab_structure(scene: PackedScene) -> bool:
	var inst := scene.instantiate() as Node3D
	var valid = inst.has_node("Connectors/Entry") and inst.has_node("Connectors/Exit") and inst.has_node("BoundsArea/CollisionShape3D")
	inst.queue_free()
	return valid


# ==============================================================================
# 3. CORE LAYOUT GENERATION
# ==============================================================================
func generate_spawn_room_first() -> void:
	var room := start_room_scene.instantiate() as Node3D
	room.name = "Room_0"
	room.global_transform = Transform3D.IDENTITY
	room_container.add_child(room)
	generated_rooms.append(room)
	await get_tree().physics_frame
	await get_tree().physics_frame


func build_room_sequence(start_tf: Transform3D, count: int, is_branch: bool, placed_aabbs: Array) -> Dictionary:
	var current_tf = start_tf
	var last_was_arena = false
	var forced_straight_count = 0
	var room_transforms: Array[Transform3D] = []
	var room_scenes: Array[PackedScene] = []
	
	var current_max_arenas = max_main_arenas + ((dungeon_loop - 1) * extra_arenas_per_loop)
	
	for i in range(1, count + 1):
		var selected_scene: PackedScene = null
		var selected_inst: Node3D = null
		var candidate_tf = Transform3D.IDENTITY
		var next_tf = Transform3D.IDENTITY
		var global_aabb = AABB()
		
		# Splitter Room restriction: Only spawns after room 5
		if not is_branch and not splitter_has_spawned and i >= 6 and splitter_room_scene != null:
			selected_scene = splitter_room_scene
			splitter_has_spawned = true
			var inst = selected_scene.instantiate() as Node3D
			var bounds = inst.get_node("BoundsArea/CollisionShape3D") as CollisionShape3D
			var entry = inst.get_node("Connectors/Entry") as Node3D
			var exit_b = inst.get_node("Connectors/ExitB") as Node3D
			var exit_a = inst.get_node("Connectors/ExitA") as Node3D
			
			var local_aabb = bounds.shape.get_debug_mesh().get_aabb() if bounds.shape.has_method("get_debug_mesh") else AABB(Vector3(-2,-2,-2), Vector3(4,4,4))
			candidate_tf = current_tf * entry.transform.inverse()
			global_aabb = (candidate_tf * local_aabb).abs()
			
			var overlapping = placed_aabbs.any(func(ex): return ex.intersects(global_aabb))
			if not overlapping:
				placed_aabbs.append(global_aabb)
				room_transforms.append(candidate_tf)
				room_scenes.append(selected_scene)
				inst.queue_free()
				
				var branch_data = build_room_sequence(candidate_tf * exit_b.transform, 5, true, placed_aabbs)
				all_branches.append(branch_data)
				current_tf = candidate_tf * exit_a.transform
				continue
			else:
				inst.queue_free()

		var room_found = false
		for attempt in range(max_attempts_per_room):
			var must_be_straight = (is_branch and i == 1) or (forced_straight_count > 0)
			var scene = pick_room_for_director(i, must_be_straight, last_was_arena, is_branch, current_max_arenas)
			if not scene: break
			
			var inst = scene.instantiate() as Node3D
			var meta = inst.get_node_or_null("Metadata")
			var tags = []
			if meta and "room_type" in meta:
				for t in meta.room_type: tags.append(t.to_lower())
			
			var is_straight = "straight" in tags or "corridor" in tags
			var bounds = inst.get_node("BoundsArea/CollisionShape3D") as CollisionShape3D
			var exit = inst.get_node("Connectors/Exit") as Node3D
			var entry = inst.get_node("Connectors/Entry") as Node3D
			
			var local_aabb = bounds.shape.get_debug_mesh().get_aabb() if bounds.shape.has_method("get_debug_mesh") else AABB(Vector3(-2,-2,-2), Vector3(4,4,4))
			candidate_tf = current_tf * entry.transform.inverse()
			global_aabb = (candidate_tf * local_aabb).abs()
			
			if placed_aabbs.any(func(ex): return ex.intersects(global_aabb)):
				inst.queue_free(); continue
			
			var is_arena = is_room_arena(scene)
			if is_branch:
				var force_arena = (i == 2 or i == 4)
				if force_arena != is_arena: inst.queue_free(); continue
			else:
				if is_arena and (main_arena_count >= current_max_arenas or last_was_arena):
					inst.queue_free(); continue
			
			next_tf = candidate_tf * exit.transform
			forced_straight_count = required_straights_after_turn if not is_straight else max(0, forced_straight_count - 1)
			
			selected_scene = scene
			selected_inst = inst
			room_found = true
			break
			
		if not room_found: break
		
		selected_inst.queue_free()
		placed_aabbs.append(global_aabb)
		room_transforms.append(candidate_tf)
		
		if is_branch and i == count and treasure_room_scene != null:
			room_scenes.append(treasure_room_scene)
		else:
			room_scenes.append(selected_scene)
		
		var is_arena = is_room_arena(selected_scene)
		if is_arena:
			if is_branch: branch_arena_count += 1
			else: main_arena_count += 1
			
		last_was_arena = is_arena
		current_tf = next_tf
		
	return { "scenes": room_scenes, "transforms": room_transforms }


func generate_level_aabb_layout() -> Dictionary:
	var placed_aabbs: Array[AABB] = []
	all_branches.clear()
	
	var temp_start := start_room_scene.instantiate() as Node3D
	var start_exit := temp_start.get_node("Connectors/Exit") as Node3D
	var initial_tf := temp_start.global_transform * start_exit.transform
	
	var start_bounds = temp_start.get_node("BoundsArea/CollisionShape3D") as CollisionShape3D
	if start_bounds and start_bounds.shape:
		placed_aabbs.append((start_bounds.shape.get_debug_mesh().get_aabb()).abs())
	temp_start.queue_free()

	var current_room_count = room_count + ((dungeon_loop - 1) * extra_rooms_per_loop)
	var main_layout = build_room_sequence(initial_tf, current_room_count, false, placed_aabbs)
	var room_scenes = main_layout["scenes"]
	var room_transforms = main_layout["transforms"]

	if end_room_scene != null and not room_scenes.is_empty():
		room_scenes[room_scenes.size() - 1] = end_room_scene

	return { "scenes": room_scenes, "transforms": room_transforms, "branches": all_branches }


# ==============================================================================
# 4. AI DIRECTOR & HELPERS
# ==============================================================================
func pick_room_for_director(room_index: int, force_straight: bool, last_was_arena: bool, is_branch: bool, max_arenas: int) -> PackedScene:
	if all_rooms.is_empty(): return null
	var valid_pool := []
	
	for scene in all_rooms:
		var is_arena = is_room_arena(scene)
		if not is_branch and is_arena and room_index < 5: continue
		
		if is_branch:
			var force_arena = (room_index == 2 or room_index == 4)
			if force_arena != is_arena: continue
		else:
			if is_arena and (main_arena_count >= max_arenas or last_was_arena): continue
			
		if force_straight and not ("straight" in scene.resource_path.to_lower() or "corridor" in scene.resource_path.to_lower()): continue
		valid_pool.append(scene)
		
	if valid_pool.is_empty(): return all_rooms[0]
	return valid_pool[rng.randi() % valid_pool.size()]


func is_room_arena(room_scene: PackedScene) -> bool:
	if "arena" in room_scene.resource_path.to_lower(): return true
	var inst := room_scene.instantiate() as Node3D
	var meta := inst.get_node_or_null("Metadata")
	var found = false
	if meta and "room_type" in meta:
		var r_types = meta["room_type"]
		if r_types is Array:
			for t in r_types:
				if "arena" in str(t).to_lower(): found = true; break
	inst.queue_free()
	return found


# ==============================================================================
# 5. INSTANTIATION & PORTALS
# ==============================================================================
func instantiate_rooms_incrementally(layout_data: Dictionary) -> void:
	var scenes: Array = layout_data["scenes"]
	var transforms: Array = layout_data["transforms"]
	var branches: Array = layout_data.get("branches", [])
	
	for i in range(scenes.size()):
		var scene: PackedScene = scenes[i]
		var room = scene.instantiate() as Node3D
		room.name = "Room_" + str(i + 1)
		room_container.add_child(room)
		room.global_transform = transforms[i]
		generated_rooms.append(room)
		
		spawn_enemies_in_room(room, i)
		setup_end_portal(room)

	for b_idx in range(branches.size()):
		var branch = branches[b_idx]
		var b_scenes = branch["scenes"]
		var b_transforms = branch["transforms"]
		
		for i in range(b_scenes.size()):
			var scene: PackedScene = b_scenes[i]
			var room = scene.instantiate() as Node3D
			room.name = "Branch_" + str(b_idx + 1) + "_Room_" + str(i + 1)
			room_container.add_child(room)
			room.global_transform = b_transforms[i]
			generated_rooms.append(room)
			
			spawn_enemies_in_room(room, i + 1)
			setup_end_portal(room)


func setup_end_portal(room: Node3D) -> void: 
	if not multiplayer.is_server(): return

	# 1. Regular dungeon end portal.
	var end_area := room.get_node_or_null(
		"Portal/PortalArea"
	) as Area3D

	if end_area:
		if not end_area.body_entered.is_connected(_on_portal_body_entered):
			end_area.body_entered.connect(
				_on_portal_body_entered.bind(end_area, false, false)
			)
	else:
		print("[Portal] No regular end portal in: ", room.name)

	# 2. Treasure branch entrance portal.
	# Supports either of your treasure entrance hierarchies.
	var treasure_area := room.get_node_or_null(
		"TreasurePortal/Portal/PortalArea"
	) as Area3D

	if treasure_area == null:
		treasure_area = room.get_node_or_null(
			"TreasurePortal/Area3D"
		) as Area3D

	if treasure_area:
		if not treasure_area.body_entered.is_connected(_on_portal_body_entered):
			treasure_area.body_entered.connect(
				_on_portal_body_entered.bind(treasure_area, true, false)
			)
	else:
		print("[Portal] No treasure entrance portal in: ", room.name)

	# 3. Treasure dungeon end portal.
	var treasure_end_area := room.get_node_or_null(
		"TreasureEndPortal/PortalArea"
	) as Area3D

	if treasure_end_area:
		if not treasure_end_area.body_entered.is_connected(_on_portal_body_entered):
			treasure_end_area.body_entered.connect(
				_on_portal_body_entered.bind(treasure_end_area, false, true)
			)
	else:
		print("[Portal] No treasure end portal in: ", room.name)


func _on_portal_body_entered( body: Node3D, portal_area: Area3D, is_treasure: bool, is_treasure_end: bool ) -> void: 
	if not multiplayer.is_server(): return

	if not body.is_in_group("player"):
		return

	# Prevent the same portal from triggering repeatedly.
	if not is_instance_valid(portal_area):
		return

	if not portal_area.monitoring:
		return

	portal_area.set_deferred("monitoring", false)

	if is_treasure_end:
		print("[Portal] Treasure dungeon completed!")
		restart_and_scale_dungeon()
	elif is_treasure:
		print("[Portal] Entering treasure dungeon!")
		trigger_treasure_branch(body)
	else:
		print("[Portal] Regular dungeon completed!")
		restart_and_scale_dungeon()


func spawn_enemies_in_room(room: Node3D, room_index: int) -> void:
	if room_index == 0: return
	var spawns_node = room.get_node_or_null("SpawnPoints/enemy_spawns")
	if not spawns_node or enemy_pool.is_empty(): return
	
	var meta = room.get_node_or_null("Metadata")
	var base_budget: int = meta.enemy_budget if meta and "enemy_budget" in meta else 40
	var scaled_budget = int(base_budget * pow(difficulty_multiplier_per_loop, dungeon_loop - 1))
	
	for marker in spawns_node.get_children():
		if scaled_budget <= 0: break
		var affordable = enemy_pool.filter(func(e): return e["cost"] <= scaled_budget)
		if affordable.is_empty(): break
		
		var chosen = affordable[rng.randi() % affordable.size()]
		var enemy_scene = chosen["scene"] as PackedScene
		if enemy_scene:
			scaled_budget -= chosen["cost"]
			var enemy = enemy_scene.instantiate() as Node3D
			room.add_child(enemy)
			enemy.global_transform = marker.global_transform
			enemy.add_to_group("network_enemies")
			rpc("rpc_spawn_enemy_remote", room.name, enemy_scene.resource_path, marker.global_transform)


func restart_and_scale_dungeon() -> void:
	if not multiplayer.is_server(): return
	dungeon_loop += 1
	rpc("rpc_clear_client_dungeon")
	await get_tree().process_frame 
	
	await generate_spawn_room_first()
	await get_tree().physics_frame
	
	var layout_data = generate_level_aabb_layout()
	instantiate_rooms_incrementally(layout_data)
	
	var spawn_room = room_container.get_node_or_null("Room_0")
	if spawn_room and Global.players.has(1):
		var spawn_marker = spawn_room.get_node_or_null("SpawnPoints/PlayerSpawn")
		var target_transform = spawn_marker.global_transform if spawn_marker else spawn_room.global_transform
		target_transform.origin += Vector3(0, 1.0, 0)
		var host_player = Global.players[1]
		if is_instance_valid(host_player):
			host_player.global_transform = target_transform
			host_player.velocity = Vector3.ZERO
	
	for peer in multiplayer.get_peers():
		request_world_state(peer)


func trigger_treasure_branch(player: Node3D) -> void: 
	if not multiplayer.is_server(): return

	if not is_instance_valid(player):
		return

	print("[Treasure] Generating treasure branch...")

	# Remove the existing dungeon on the server and clients.
	rpc("rpc_clear_client_dungeon")
	await get_tree().process_frame

	# Calculate the branch starting position.
	var temp_start := start_room_scene.instantiate() as Node3D

	if temp_start == null:
		push_error("[Treasure] Failed to instantiate spawn room.")
		return

	var start_exit := temp_start.get_node_or_null(
		"Connectors/Exit"
	) as Node3D

	if start_exit == null:
		temp_start.free()
		push_error("[Treasure] Spawn room is missing Connectors/Exit.")
		return

	var initial_tf: Transform3D = (
		temp_start.global_transform * start_exit.transform
	)

	temp_start.free()

	# Generate the branch layout.
	var placed_aabbs: Array[AABB] = []

	var treasure_layout := build_room_sequence(
		initial_tf,
		3,
		true,
		placed_aabbs
	)

	var scenes: Array = treasure_layout["scenes"]

	if scenes.is_empty():
		push_error("[Treasure] No rooms could be generated.")
		return

	if treasure_room_scene == null:
		push_error("[Treasure] Treasure room scene is not assigned.")
		return

	# Replace the final branch room with the treasure room.
	scenes[scenes.size() - 1] = treasure_room_scene

	# Instantiate the rooms and configure their portals.
	instantiate_rooms_incrementally(treasure_layout)

	# Position the player at the start of the new branch.
	if is_instance_valid(player):
		player.global_transform = initial_tf
		player.global_position += Vector3.UP

		if player is CharacterBody3D:
			player.velocity = Vector3.ZERO

	# Synchronize the generated rooms with connected clients.
	for peer in multiplayer.get_peers():
		request_world_state(peer)

	print("[Treasure] Treasure branch generated.")


@rpc("any_peer", "reliable")
func request_world_state(peer_id: int) -> void:
	if not multiplayer.is_server(): return
	for room in generated_rooms:
		rpc_id(peer_id, "rpc_spawn_room_remote", room.scene_file_path, room.global_transform, room.name)
		
	await get_tree().create_timer(0.5).timeout
	for room in generated_rooms:
		for child in room.get_children():
			if child.is_in_group("network_enemies"):
				rpc_id(peer_id, "rpc_spawn_enemy_remote", room.name, child.scene_file_path, child.global_transform)
				
	rpc_id(peer_id, "remote_world_ready")


@rpc("authority", "call_local", "reliable")
func rpc_clear_client_dungeon() -> void:
	for room in generated_rooms:
		if is_instance_valid(room): room.queue_free()
	generated_rooms.clear()
	main_arena_count = 0
	branch_arena_count = 0
	splitter_has_spawned = false


@rpc("authority", "call_remote", "reliable")
func rpc_spawn_room_remote(path: String, tf: Transform3D, r_name: String) -> void:
	var room = load(path).instantiate() as Node3D
	room.name = r_name
	room_container.add_child(room)
	room.global_transform = tf
	generated_rooms.append(room)


@rpc("authority", "call_remote", "reliable")
func rpc_spawn_enemy_remote(r_name: String, e_path: String, tf: Transform3D) -> void:
	var room = room_container.get_node_or_null(r_name)
	if not room:
		await get_tree().process_frame
		room = room_container.get_node_or_null(r_name)
	if room:
		var enemy = load(e_path).instantiate() as Node3D
		room.add_child(enemy)
		enemy.global_transform = tf
		enemy.add_to_group("network_enemies")


@rpc("authority", "call_remote", "reliable")
func remote_world_ready() -> void:
	emit_signal("world_ready")
	var spawn_room = room_container.get_node_or_null("Room_0")
	if spawn_room and Global.player:
		var spawn_marker = spawn_room.get_node_or_null("SpawnPoints/PlayerSpawn")
		var target_transform = spawn_marker.global_transform if spawn_marker else spawn_room.global_transform
		target_transform.origin += Vector3(0, 1.0, 0)
		Global.player.global_transform = target_transform
		Global.player.velocity = Vector3.ZERO
