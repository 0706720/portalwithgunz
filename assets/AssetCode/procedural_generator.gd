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
@export var required_straights_after_turn := 1 # Forces linear paths after turns

@export_category("Scene References")
@export var end_room_scene: PackedScene = preload("res://assets/Rooms/Special/end_room_prefab.tscn")
@export var splitter_room_scene: PackedScene = preload("res://assets/Rooms/Special/splitter_room_prefab.tscn")
@export var start_room_scene: PackedScene = preload("res://assets/Rooms/Special/spawn_room_prefab.tscn")
@export var max_arenas := 2 # Hard cap on how many arena rooms can spawn
@onready var room_container: Node3D = $"../RoomContainer"

# Runtime tracking variables
var current_arena_count := 0
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
var enemy_spawn_tallies: Dictionary = {}
var room_spawn_tallies: Dictionary = {}


# ==============================================================================
# 2. INITIALIZATION & SETUP (_ready)
# ==============================================================================
func _ready() -> void:
	enemy_spawn_tallies.clear()
	room_spawn_tallies.clear()
	current_arena_count = 0
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
			
			# Instantly build the rooms and distribute enemies
			await instantiate_rooms_incrementally(layout_data["paths"], layout_data["transforms"])
			
			level_generated = true
			emit_signal("world_ready")
		else:
			push_error("[ProceduralGen] Generator setup validation failed.")
	else:
		# Clients request the compiled layout state from the server
		rpc_id(1, "request_world_state", multiplayer.get_unique_id())


func validate_generator_setup() -> bool:
	return room_container != null and not all_rooms.is_empty()


func load_room_prefabs() -> void:
	all_rooms.clear()
	scan_folder_for_rooms("res://assets/Rooms/")
	print("[Gen] Total valid rooms loaded: ", all_rooms.size())


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
				
				# Safely skip special prefabs (Start, End, Splitter) so they aren't added to the random pool
				var skip := false
				if start_room_scene != null and full_path == start_room_scene.resource_path: skip = true
				if end_room_scene != null and full_path == end_room_scene.resource_path: skip = true
				if splitter_room_scene != null and full_path == splitter_room_scene.resource_path: skip = true
				
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
func build_room_sequence(start_tf: Transform3D, count: int, is_branch: bool, placed_aabbs: Array, room_transforms: Array, room_scene_paths: Array) -> Transform3D:
	var current_tf = start_tf
	var last_was_arena = false
	var forced_straight_count = 0
	
	for i in range(1, count + 1):
		var selected_scene: PackedScene = null
		var selected_inst: Node3D = null
		var candidate_tf = Transform3D.IDENTITY
		var next_tf = Transform3D.IDENTITY
		var global_aabb = AABB()
		
		# Handle Splitter Room Hub insertion exclusively on the main path at index 4
		if not is_branch and not splitter_has_spawned and i == 4 and splitter_room_scene != null:
			if rng.randf() < 0.4: # 40% chance to trigger split
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
				
				# Check if splitter overlaps with anything already placed
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
					
					# Recursively build Branch B as an independent side sequence (Arenas allowed here!)
					build_room_sequence(candidate_tf * exit_b.transform, 5, true, placed_aabbs, room_transforms, room_scene_paths)
					
					# Keep main generator moving forward through Exit A
					current_tf = candidate_tf * exit_a.transform
					continue
				else:
					inst.queue_free()

		# Standard Room Selection Loop
		var room_found = false
		var must_be_straight = false
		
		for attempt in range(max_attempts_per_room):
			must_be_straight = (forced_straight_count > 0)
			var scene = pick_room_for_director(i, must_be_straight, last_was_arena)
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
			
			# Overlap check
			var overlapping = false
			for ex in placed_aabbs:
				if ex.intersects(global_aabb): overlapping = true; break
			if overlapping: inst.queue_free(); continue
			
			# Arena Rules: ONLY force/allow arenas if we are currently building a side branch!
			var is_arena = is_room_arena(scene)
			if not is_branch:
				if is_arena: inst.queue_free(); continue # Main path never gets arenas
			else:
				var force_arena = (i == 2 or i == 4)
				if force_arena and not is_arena: inst.queue_free(); continue
				if not force_arena and is_arena and (current_arena_count >= max_arenas or last_was_arena): inst.queue_free(); continue
			
			next_tf = candidate_tf * exit.transform
			forced_straight_count = required_straights_after_turn if not is_straight else max(0, forced_straight_count - 1)
			
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
		room_scene_paths.append(selected_scene.resource_path)
		
		var is_arena = is_room_arena(selected_scene)
		if is_arena: current_arena_count += 1
		last_was_arena = is_arena
		
		var name_key = selected_scene.resource_path.get_file().get_basename()
		room_spawn_tallies[name_key] = room_spawn_tallies.get(name_key, 0) + 1
		current_tf = next_tf
		
	return current_tf


func generate_level_aabb_layout() -> Dictionary:
	var placed_aabbs: Array[AABB] = []
	var room_transforms: Array[Transform3D] = []
	var room_scene_paths: Array[String] = []
	
	var temp_start := start_room_scene.instantiate() as Node3D
	var start_exit := temp_start.get_node("Connectors/Exit") as Node3D
	var initial_tf := temp_start.global_transform * start_exit.transform
	
	var start_bounds = temp_start.get_node("BoundsArea/CollisionShape3D") as CollisionShape3D
	if start_bounds and start_bounds.shape:
		placed_aabbs.append((start_bounds.shape.get_debug_mesh().get_aabb()).abs())
	temp_start.queue_free()

	# 1. Run main path generation sequence using our reusable builder function
	build_room_sequence(initial_tf, room_count, false, placed_aabbs, room_transforms, room_scene_paths)

	# 2. Force the designated End Room onto the absolute final slot of the primary path
	if end_room_scene != null and not room_scene_paths.is_empty():
		room_scene_paths[room_scene_paths.size() - 1] = end_room_scene.resource_path

	return { "paths": room_scene_paths, "transforms": room_transforms }


# ==============================================================================
# 4. AI DIRECTOR & HELPERS
# ==============================================================================
func pick_room_for_director(room_index: int, force_straight: bool, last_was_arena: bool) -> PackedScene:
	if all_rooms.is_empty(): return null
	var valid_pool := []
	
	for scene in all_rooms:
		var is_arena = is_room_arena(scene)
		if is_arena and (last_was_arena or current_arena_count >= max_arenas): continue
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
				if "arena" in str(t).to_lower():
					found = true
					break
	inst.queue_free()
	return found


# ==============================================================================
# 5. INCREMENTAL INSTANTIATION & MULTIPLAYER SYNCHRONIZATION
# ==============================================================================
func instantiate_rooms_incrementally(paths: Array[String], transforms: Array[Transform3D]) -> void:
	for i in range(paths.size()):
		var scene = load(paths[i]) as PackedScene
		var room = scene.instantiate() as Node3D
		room.name = "Room_" + str(i + 1)
		room_container.add_child(room)
		room.global_transform = transforms[i]
		generated_rooms.append(room)
		
		spawn_enemies_in_room(room, i)
		
		if i % 3 == 0: await get_tree().process_frame


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
		var enemy = chosen["scene"].instantiate() as Node3D
		room.add_child(enemy)
		enemy.global_transform = marker.global_transform
		
		rpc("rpc_spawn_enemy_remote", room.name, chosen["scene"].resource_path, marker.global_transform)
		budget -= chosen["cost"]


@rpc("any_peer", "reliable")
func request_world_state(peer_id: int) -> void:
	if not multiplayer.is_server(): return
	for room in generated_rooms:
		rpc_id(peer_id, "rpc_spawn_room_remote", room.scene_file_path, room.global_transform)
	rpc_id(peer_id, "remote_world_ready")

@rpc("authority", "call_remote", "reliable")
func rpc_spawn_room_remote(path: String, tf: Transform3D) -> void:
	var room = load(path).instantiate() as Node3D
	room_container.add_child(room)
	room.global_transform = tf
	generated_rooms.append(room)

@rpc("authority", "call_remote", "reliable")
func rpc_spawn_enemy_remote(r_name: String, e_path: String, tf: Transform3D) -> void:
	var room = room_container.get_node_or_null(r_name)
	if room:
		var enemy = load(e_path).instantiate() as Node3D
		room.add_child(enemy)
		enemy.global_transform = tf

@rpc("authority", "call_remote", "reliable")
func remote_world_ready() -> void:
	emit_signal("world_ready")
