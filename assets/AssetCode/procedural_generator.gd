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
@export var required_straights_after_turn := 0 # Forces linear paths after turns

@export_category("Scene References")
@export var end_room_scene: PackedScene = preload("res://assets/Rooms/Special/end_room_prefab.tscn")
@export var splitter_room_scene: PackedScene = preload("res://assets/Rooms/Special/splitter_room_prefab.tscn")
@export var start_room_scene: PackedScene = preload("res://assets/Rooms/Special/spawn_room_prefab.tscn")
@export var treasure_room_scene: PackedScene = preload("res://assets/Rooms/Special/treasure_room_prefab.tscn") 
@onready var room_container: Node3D = $"../RoomContainer"

@export_category("Arena Settings")
@export var max_main_arenas := 2 # Hard cap on how many arena rooms can spawn
@export var branch_arena_target := 2 # Exact number of arenas forced on the side branch

# Runtime tracking variables
var main_arena_count := 0
var branch_arena_count := 0
var splitter_has_spawned := false

@export_category("Enemy Point-Buy System")
@export var enemy_spawn_chance := 0.7
@export var enemy_pool: Array[Dictionary] = [
	{"scene": preload("res://assets/Enemies/bat.tscn"), "cost": 4},
	{"scene": preload("res://assets/Enemies/goblin.tscn"), "cost": 5},
	{"scene": preload("res://assets/Enemies/skeleton_archer.tscn"), "cost": 10},
	{"scene": preload("res://assets/Enemies/sorcerer.tscn"), "cost": 15},
	{"scene": preload("res://assets/Enemies/warlock.tscn"), "cost": 15},
	{"scene": preload("res://assets/Enemies/orc.tscn"), "cost": 20},
	{"scene": preload("res://assets/Enemies/elite_crossbower.tscn"), "cost": 30},
	{"scene": preload("res://assets/Enemies/elite_knight.tscn"), "cost": 35},
]

# Internal states
var level_generated := false
var rng := RandomNumberGenerator.new()
var all_rooms: Array[PackedScene] = []
var generated_rooms: Array[Node3D] = []
var last_turn_direction := ""
var all_branches: Array = []
var enemy_spawn_tallies: Dictionary = {}
var room_spawn_tallies: Dictionary = {}


# ==============================================================================
# 2. INITIALIZATION & SETUP (_ready)
# ==============================================================================
func _ready() -> void:
	enemy_spawn_tallies.clear()
	room_spawn_tallies.clear()
	main_arena_count = 0
	splitter_has_spawned = false
	
	set_process_input(true)
	
	# Only the server handles procedural generation to maintain a single source of truth
	if multiplayer.is_server():
		rng.randomize()
		load_room_prefabs()
		
		if validate_generator_setup():
			await generate_spawn_room_first()
			
			# Calculate all positions via fast AABB math before instantiating visually
			var layout_data = generate_level_aabb_layout()
			
			# FIX: Pass the full dictionary so branches and treasure rooms get instantiated!
			await instantiate_rooms_incrementally(layout_data)
			
			level_generated = true
			emit_signal("world_ready")
		else:
			push_error("[ProceduralGen] Generator setup validation failed.")
	else:
		# Clients request the compiled layout state from the server
		rpc_id(1, "request_world_state", multiplayer.get_unique_id())


func load_room_prefabs() -> void:
	all_rooms.clear()
	scan_folder_for_rooms("res://assets/Rooms/")
	print("[Gen] Total valid rooms loaded: ", all_rooms.size())


func validate_generator_setup() -> bool:
	return room_container != null and not all_rooms.is_empty()


# Recursively scans directory for usable room .tscn files while filtering out special prefabs and work-in-progress folders
func scan_folder_for_rooms(dir_path: String) -> void:
	# Skip the InDevelopment folder entirely
	if "InDevelopment" in dir_path:
		return
		
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
				
				# Safely skip special prefabs (Start, End, Splitter, Treasure) so they aren't added to the random pool
				var skip := false
				if start_room_scene != null and full_path == start_room_scene.resource_path: skip = true
				if end_room_scene != null and full_path == end_room_scene.resource_path: skip = true
				if splitter_room_scene != null and full_path == splitter_room_scene.resource_path: skip = true
				if treasure_room_scene != null and full_path == treasure_room_scene.resource_path: skip = true 
				
				if skip:
					file_name = dir.get_next()
					continue
				
				var scene := load(full_path) as PackedScene
				if scene and validate_prefab_structure(scene): 
					all_rooms.append(scene)
					
		file_name = dir.get_next()
	dir.list_dir_end()

func validate_prefab_structure(scene: PackedScene) -> bool:
	var inst := scene.instantiate() as Node3D
	var valid = inst.has_node("Connectors/Entry") and inst.has_node("Connectors/Exit") and inst.has_node("BoundsArea/CollisionShape3D")
	if not valid:
		print("[Gen] Room failed validation: ", scene.resource_path)
	inst.queue_free()
	return valid


# ==============================================================================
# 3. CORE GENERATION & REUSABLE BUILDER
# ==============================================================================
func generate_spawn_room_first() -> void:
	var room := start_room_scene.instantiate() as Node3D
	room.name = "Room_0"
	room.global_transform = Transform3D.IDENTITY
	room_container.add_child(room)
	generated_rooms.append(room)
	await get_tree().physics_frame
	await get_tree().physics_frame


# REUSABLE BUILDER: Handles main dungeon path and side branches cleanly
func build_room_sequence(start_tf: Transform3D, count: int, is_branch: bool, placed_aabbs: Array) -> Dictionary:
	var current_tf = start_tf
	var last_was_arena = false
	var forced_straight_count = 0
	var room_transforms: Array[Transform3D] = []
	var room_scene_paths: Array[String] = []
	
	for i in range(1, count + 1):
		var selected_scene: PackedScene = null
		var selected_inst: Node3D = null
		var candidate_tf = Transform3D.IDENTITY
		var next_tf = Transform3D.IDENTITY
		var global_aabb = AABB()
		
		# Handle Splitter Room Hub insertion exclusively on the main path at index 4
		if not is_branch and not splitter_has_spawned and i == 4 and splitter_room_scene != null:
			selected_scene = splitter_room_scene
			splitter_has_spawned = true
			var inst = selected_scene.instantiate() as Node3D
			var bounds = inst.get_node("BoundsArea/CollisionShape3D") as CollisionShape3D
			var entry = inst.get_node("Connectors/Entry") as Node3D
			var exit_a = inst.get_node("Connectors/ExitA") as Node3D
			var exit_b = inst.get_node("Connectors/ExitB") as Node3D
			
			var local_aabb = bounds.shape.get_debug_mesh().get_aabb() if bounds.shape.has_method("get_debug_mesh") else AABB(Vector3(-2,-2,-2), Vector3(4,4,4))
			candidate_tf = current_tf * entry.transform.inverse()
			global_aabb = (candidate_tf * local_aabb).abs()
			
			var overlapping = false
			for ex in placed_aabbs:
				if ex.intersects(global_aabb): overlapping = true; break
			
			if not overlapping:
				placed_aabbs.append(global_aabb)
				room_transforms.append(candidate_tf)
				room_scene_paths.append(selected_scene.resource_path)
				
				var splitter_name = selected_scene.resource_path.get_file().get_basename()
				room_spawn_tallies[splitter_name] = room_spawn_tallies.get(splitter_name, 0) + 1
				inst.queue_free()
				
				# Build Branch B independently and store it in our global tracking array
				var branch_data = build_room_sequence(candidate_tf * exit_b.transform, 5, true, placed_aabbs)
				all_branches.append(branch_data)
				
				current_tf = candidate_tf * exit_a.transform
				continue
			else:
				inst.queue_free()

		# Standard Room Selection Loop
		var room_found = false
		var must_be_straight = false
		
		for attempt in range(max_attempts_per_room):
			must_be_straight = (forced_straight_count > 0)
			var scene = pick_room_for_director(i, must_be_straight, last_was_arena, is_branch)
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
			
			var overlapping = false
			for ex in placed_aabbs:
				if ex.intersects(global_aabb): overlapping = true; break
			if overlapping: inst.queue_free(); continue
			
			# Arena Rules Split Logic
			var is_arena = is_room_arena(scene)
			if is_branch:
				var force_arena = (i == 2 or i == 4)
				if force_arena and not is_arena: inst.queue_free(); continue
				if not force_arena and is_arena: inst.queue_free(); continue 
			else:
				if is_arena and (main_arena_count >= max_main_arenas or last_was_arena):
					inst.queue_free()
					continue
			
			next_tf = candidate_tf * exit.transform
			
			if required_straights_after_turn > 0:
				forced_straight_count = required_straights_after_turn if not is_straight else max(0, forced_straight_count - 1)
			else:
				forced_straight_count = 0
			
			selected_scene = scene
			selected_inst = inst
			room_found = true
			break
			
		if not room_found: 
			print("[Gen] Failed to find a valid room at index: ", i, " on path (is_branch: ", is_branch, ")")
			break
		
		selected_inst.queue_free()
		placed_aabbs.append(global_aabb)
		room_transforms.append(candidate_tf)
		
		# If this is the very last room of a side branch, force it to be the Treasure Room!
		if is_branch and i == count and treasure_room_scene != null:
			room_scene_paths.append(treasure_room_scene.resource_path)
		else:
			room_scene_paths.append(selected_scene.resource_path)
		
		var is_arena = is_room_arena(selected_scene)
		if is_arena:
			if is_branch: branch_arena_count += 1
			else: main_arena_count += 1
			
		last_was_arena = is_arena
		
		var name_key = selected_scene.resource_path.get_file().get_basename()
		room_spawn_tallies[name_key] = room_spawn_tallies.get(name_key, 0) + 1
		current_tf = next_tf
		
	return { "paths": room_scene_paths, "transforms": room_transforms }


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

	# 1. Run main path generation sequence
	var main_layout = build_room_sequence(initial_tf, room_count, false, placed_aabbs)
	var room_scene_paths = main_layout["paths"]
	var room_transforms = main_layout["transforms"]

	# 2. Force the designated End Room onto the absolute final slot of the primary path
	if end_room_scene != null and not room_scene_paths.is_empty():
		room_scene_paths[room_scene_paths.size() - 1] = end_room_scene.resource_path

	return { "paths": room_scene_paths, "transforms": room_transforms, "branches": all_branches }


# ==============================================================================
# 4. AI DIRECTOR & HELPERS
# ==============================================================================
func pick_room_for_director(room_index: int, force_straight: bool, last_was_arena: bool, is_branch: bool) -> PackedScene:
	if all_rooms.is_empty(): return null
	var valid_pool := []
	
	for scene in all_rooms:
		var is_arena = is_room_arena(scene)
		if is_branch:
			var force_arena = (room_index == 2 or room_index == 4)
			if force_arena and not is_arena: continue
			if not force_arena and is_arena: continue
		else:
			if is_arena and (main_arena_count >= max_main_arenas or last_was_arena): continue
			
		if force_straight and not ("straight" in scene.resource_path.to_lower() or "corridor" in scene.resource_path.to_lower()): continue
		valid_pool.append(scene)
		
	if valid_pool.is_empty(): return all_rooms[0]
	return valid_pool[rng.randi() % valid_pool.size()]


#func spawn_enemies_in_room(room: Node3D, room_index: int) -> void:
	#if room_index == 0: return
	#var spawns_node = room.get_node_or_null("SpawnPoints/enemy_spawns")
	#if not spawns_node or enemy_pool.is_empty(): return
	#
	#var meta = room.get_node_or_null("Metadata")
	#var budget: int = meta.enemy_budget if meta and "enemy_budget" in meta else 40
	#
	#for marker in spawns_node.get_children():
		#if budget <= 0: break
		#var affordable = enemy_pool.filter(func(e): return e["cost"] <= budget)
		#if affordable.is_empty(): break
		#
		#var chosen = affordable[rng.randi() % affordable.size()]
		#var enemy = chosen["scene"].instantiate() as Node3D
		#room.add_child(enemy)
		#enemy.global_transform = marker.global_transform


func is_room_arena(room_scene: PackedScene) -> bool:
	if "arena" in room_scene.resource_path.to_lower(): return true
	var inst := room_scene.instantiate() as Node3D
	var meta := inst.get_node_or_null("Metadata")
	var found = false
	if meta and "room_type" in meta:
		var r_types = meta["room_type"]
		if r_types is Array:
			for t in r_types:
				if "arena" in str(t).to_lower():
					found = true
					break
	inst.queue_free()
	return found


# ==============================================================================
# 5. INCREMENTAL INSTANTIATION & MULTIPLAYER SYNCHRONIZATION
# ==============================================================================
func instantiate_rooms_incrementally(layout_data: Dictionary) -> void:
	var paths: Array = layout_data["paths"]
	var transforms: Array = layout_data["transforms"]
	var branches: Array = layout_data.get("branches", [])
	
	# Instantiate Main Path
	for i in range(paths.size()):
		var scene = load(paths[i]) as PackedScene
		var room = scene.instantiate() as Node3D
		room.name = "Room_" + str(i + 1)
		room_container.add_child(room)
		room.global_transform = transforms[i]
		generated_rooms.append(room)
		
		spawn_enemies_in_room(room, i)
		
		if i % 3 == 0: await get_tree().process_frame

	# Instantiate Side Branches (including the Treasure Room at the end of each branch)
	for b_idx in range(branches.size()):
		var branch = branches[b_idx]
		var b_paths = branch["paths"]
		var b_transforms = branch["transforms"]
		
		for i in range(b_paths.size()):
			var scene = load(b_paths[i]) as PackedScene
			var room = scene.instantiate() as Node3D
			room.name = "Branch_" + str(b_idx + 1) + "_Room_" + str(i + 1)
			room_container.add_child(room)
			room.global_transform = b_transforms[i]
			generated_rooms.append(room)
			
			spawn_enemies_in_room(room, i + 1)
			
			await get_tree().process_frame


func spawn_enemies_in_room(room: Node3D, room_index: int) -> void:
	if room_index == 0: return
	var spawns_node = room.get_node_or_null("SpawnPoints/enemy_spawns")
	if not spawns_node or enemy_pool.is_empty(): return
	
	var meta = room.get_node_or_null("Metadata")
	var budget: int = meta.enemy_budget if meta and "enemy_budget" in meta else 40
	
	for marker in spawns_node.get_children():
		if budget <= 0: break
		var affordable = enemy_pool.filter(func(e): return e["cost"] <= budget)
		if affordable.is_empty(): break
		
		var chosen = affordable[rng.randi() % affordable.size()]
		var enemy_scene = chosen["scene"] as PackedScene
		if enemy_scene:
			budget -= chosen["cost"]
			
			# 1. Instantiate locally on the server
			var enemy = enemy_scene.instantiate() as Node3D
			room.add_child(enemy)
			enemy.global_transform = marker.global_transform
			enemy.add_to_group("network_enemies") # Tag it for easy syncing
			
			# 2. Broadcast to all connected clients live
			rpc("rpc_spawn_enemy_remote", room.name, enemy_scene.resource_path, marker.global_transform)


@rpc("any_peer", "reliable")
func request_world_state(peer_id: int) -> void:
	if not multiplayer.is_server(): return
	
	# 1. Send all rooms first so the structure exists on the client
	for i in range(generated_rooms.size()):
		var room = generated_rooms[i]
		rpc_id(peer_id, "rpc_spawn_room_remote", room.scene_file_path, room.global_transform, room.name)
		
	# 2. Wait briefly for rooms to instantiate, then sync their enemies
	await get_tree().create_timer(0.5).timeout
	for room in generated_rooms:
		for child in room.get_children():
			if child.is_in_group("network_enemies"):
				rpc_id(peer_id, "rpc_spawn_enemy_remote", room.name, child.scene_file_path, child.global_transform)
				
	# 3. Tell the client the world is fully built and ready!
	rpc_id(peer_id, "remote_world_ready")


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
		# If the room hasn't finished instantiating yet, wait a frame and try once more
		await get_tree().process_frame
		room = room_container.get_node_or_null(r_name)
		
	if room:
		var enemy = load(e_path).instantiate() as Node3D
		room.add_child(enemy)
		enemy.global_transform = tf
		enemy.add_to_group("network_enemies")
	else:
		print("[Gen] Warning: Failed to spawn enemy because room node '", r_name, "' was not found.")


@rpc("authority", "call_remote", "reliable")
func remote_world_ready() -> void:
	emit_signal("world_ready")
