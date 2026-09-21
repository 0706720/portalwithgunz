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
@export var required_straights_after_turn := 10 # Forces longer linear paths after turns

@export_category("Scene References")
@export var start_room_scene: PackedScene = preload("res://assets/Rooms/Special/spawn_room_prefab1.tscn")
@onready var room_container: Node3D = $"../RoomContainer"

@export_category("Enemy Point-Buy System")
@export var enemy_spawn_chance := 0.7 # 70% chance to populate an available marker
@export var enemy_pool: Array[Dictionary] = [
	{"scene": preload("res://assets/Enemies/bat.tscn"), "cost": 4},
	{ "scene": preload("res://assets/Enemies/goblin.tscn"), "cost": 5 },
	{ "scene": preload("res://assets/Enemies/skeleton_archer.tscn"), "cost": 10 },
	{ "scene": preload("res://assets/Enemies/sorcerer.tscn"), "cost": 15 },
	{ "scene": preload("res://assets/Enemies/warlock.tscn"), "cost": 15 },
	{ "scene": preload("res://assets/Enemies/orc.tscn"), "cost": 20 },
	{ "scene": preload("res://assets/Enemies/elite_crossbower.tscn"), "cost": 30 },
	{ "scene": preload("res://assets/Enemies/elite_knight.tscn"), "cost": 35 },
]

# Internal runtime states
var level_generated := false
var rng := RandomNumberGenerator.new()
var all_rooms: Array[PackedScene] = []
var generated_rooms: Array[Node3D] = []
var last_turn_direction := "" # Tracks "left" or "right" to prevent coiling loops
var enemy_spawn_tallies: Dictionary = {}


# ==============================================================================
# 2. INITIALIZATION & SERVER ROUTING (_ready)
# ==============================================================================
func _ready() -> void:
	enemy_spawn_tallies.clear()
	print_rich("[color=cyan][ProceduralGen] Initializing generator. Is Server: %s[/color]" % multiplayer.is_server())
	set_process_input(true)

	if multiplayer.is_server():
		rng.randomize()
		load_room_prefabs()

		if validate_generator_setup():
			# Step A: Spawn Room 0 first and let physics settle for safe player drops
			await generate_spawn_room_first()
			
			# Step B: Compute valid non-overlapping coordinates via fast AABB math
			var layout_data = generate_level_aabb_layout()
			
			# Step C: Incrementally instantiate rooms and populate enemies over multiple frames
			await instantiate_rooms_incrementally(layout_data["paths"], layout_data["transforms"])
			
			level_generated = true
			emit_signal("world_ready")
		else:
			push_error("[ProceduralGen] Generator setup validation failed. Aborting generation.")
	else:
		# Clients request the compiled world state layout from the server
		rpc_id(1, "request_world_state", multiplayer.get_unique_id())


# ==============================================================================
# 3. SETUP VALIDATION & PREFAB LOADER (IO)
# ==============================================================================
func validate_generator_setup() -> bool:
	print_rich("[color=yellow][ProceduralGen] Validating generator setup...[/color]")
	var is_valid := true

	if room_container == null:
		push_error("[ProceduralGen] Setup Error: 'room_container' node reference is missing.")
		is_valid = false
	if start_room_scene == null:
		push_warning("[ProceduralGen] Setup Warning: 'start_room_scene' is not set.")
	if all_rooms.is_empty():
		push_error("[ProceduralGen] Setup Error: No room prefabs loaded in 'all_rooms'.")
		is_valid = false

	if is_valid:
		print_rich("[color=green][ProceduralGen] Setup validation passed successfully![/color]")
	return is_valid


func load_room_prefabs() -> void:
	all_rooms.clear()
	scan_folder_for_rooms("res://assets/Rooms/")
	print_rich("[color=green][ProceduralGen] Prefab Loader: Loaded %d total usable room prefabs.[/color]" % all_rooms.size())


func scan_folder_for_rooms(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("[ProceduralGen] IO Error: Could not open directory at '%s'" % dir_path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()

	while file_name != "":
		if dir.current_is_dir():
			if not file_name.begins_with("."):
				scan_folder_for_rooms(dir_path + file_name + "/")
		else:
			if file_name.ends_with(".tscn"):
				var full_path := dir_path + file_name
				if start_room_scene != null and full_path == start_room_scene.resource_path:
					file_name = dir.get_next()
					continue

				var scene := load(full_path) as PackedScene
				if scene:
					if validate_prefab_structure(scene, full_path):
						all_rooms.append(scene)
				else:
					push_error("[ProceduralGen] Load Error: Failed to load scene file at '%s'" % full_path)
		file_name = dir.get_next()
	dir.list_dir_end()


func validate_prefab_structure(scene: PackedScene, path: String) -> bool:
	var temp_inst := scene.instantiate() as Node3D
	var valid := true

	if not temp_inst.has_node("Connectors/Entry"):
		push_warning("[ProceduralGen] Prefab Warning: '%s' is missing 'Connectors/Entry'." % path)
		valid = false
	if not temp_inst.has_node("Connectors/Exit"):
		push_warning("[ProceduralGen] Prefab Warning: '%s' is missing 'Connectors/Exit'." % path)
		valid = false
	if not temp_inst.has_node("BoundsArea/CollisionShape3D"):
		push_warning("[ProceduralGen] Prefab Warning: '%s' is missing 'BoundsArea/CollisionShape3D'." % path)
		valid = false

	temp_inst.queue_free()
	return valid


# ==============================================================================
# 4. AI DIRECTOR & ROOM SELECTION LOGIC
# ==============================================================================
func pick_room_for_director(room_index: int, force_straight: bool = false) -> PackedScene:
	if all_rooms.is_empty():
		return null

	# Fetch AI Director stats if available, otherwise fallback to defaults
	var current_diff: float = AI_Director.dynamic_difficulty if Engine.has_singleton("AI_Director") else 0.2
	var pacing: int = AI_Director.current_pacing if Engine.has_singleton("AI_Director") else 0
	var scored_rooms: Array = []

	# Evaluate every loaded room option against current game pacing and layout constraints
	for room_scene in all_rooms:
		var inst := room_scene.instantiate() as Node3D
		var meta := inst.get_node_or_null("Metadata")
		var diff: float = meta.difficulty_weight if meta else 0.0
		var tags: Array[String] = []
		if meta:
			for t in meta.room_type:
				tags.append(t.to_lower())
		inst.queue_free()

		var is_straight := "straight" in tags or "corridor" in tags
		var is_left_turn := "turn_left" in tags or "left" in tags
		var is_right_turn := "turn_right" in tags or "right" in tags

		# Task: Enforce hard constraint if a straight hallway buffer is required
		if force_straight and not is_straight:
			continue

		var score: float = 1.0

		# Task: Apply anti-coiling logic to favor alternating turns over looping
		if is_left_turn:
			if last_turn_direction == "right": score *= 3.0
			elif last_turn_direction == "left": score *= 0.2
		elif is_right_turn:
			if last_turn_direction == "left": score *= 3.0
			elif last_turn_direction == "right": score *= 0.2

		# Task: Adjust score based on dynamic difficulty variance
		var diff_delta := diff - current_diff
		if diff_delta > 0.0:
			score *= max(0.1, 1.0 - diff_delta)

		# Task: Apply weighting multipliers depending on the current pacing state
		match pacing:
			AI_Director.PacingState.BUILDUP:
				if is_straight: score *= 2.0
				if "arena" in tags: score *= 0.2
			AI_Director.PacingState.PEAK:
				if "arena" in tags: score *= 3.0
				if is_straight: score *= 0.5
			AI_Director.PacingState.RELAX:
				if "safe" in tags or is_straight: score *= 2.5

		scored_rooms.append({ "scene": room_scene, "score": max(score, 0.05) })

	# Task: Fallback handler if strict filtering cleared out all choices
	if scored_rooms.is_empty() and force_straight:
		var straight_fallbacks: Array[PackedScene] = []
		for room_scene in all_rooms:
			var inst := room_scene.instantiate() as Node3D
			var meta := inst.get_node_or_null("Metadata")
			var tags: Array = meta.room_type if meta else []
			var is_s := false
			for t in tags:
				if t.to_lower() == "straight" or t.to_lower() == "corridor": is_s = true
			inst.queue_free()
			if is_s: straight_fallbacks.append(room_scene)
		
		if not straight_fallbacks.is_empty():
			return straight_fallbacks[rng.randi() % straight_fallbacks.size()]
		return all_rooms[rng.randi() % all_rooms.size()]

	# Task: Perform weighted random selection roll across final scored choices
	var total: float = 0.0
	for r in scored_rooms: total += r.score
	if total <= 0.0: return all_rooms[rng.randi() % all_rooms.size()]

	var pick := rng.randf() * total
	var accum := 0.0
	for r in scored_rooms:
		accum += r.score
		if accum >= pick: return r.scene

	return all_rooms[rng.randi() % all_rooms.size()]


# ==============================================================================
# 5. LAYOUT CALCULATION & AABB MATH
# ==============================================================================
func generate_spawn_room_first() -> void:
	var room := start_room_scene.instantiate() as Node3D
	room.name = "Room_0"
	room.global_transform = Transform3D.IDENTITY
	room_container.add_child(room)
	generated_rooms.append(room)
	
	await get_tree().physics_frame
	await get_tree().physics_frame
	print_rich("[color=green][ProceduralGen] Spawn room loaded. Player can safely drop in.[/color]")


func generate_level_aabb_layout() -> Dictionary:
	print_rich("[color=cyan][ProceduralGen] --- Starting Linear AABB Layout Calculation ---[/color]")
	
	var placed_aabbs: Array[AABB] = []
	var room_transforms: Array[Transform3D] = []
	var room_scene_paths: Array[String] = []
	var forced_straight_count := 0
	
	var temp_start := start_room_scene.instantiate() as Node3D
	var start_exit := temp_start.get_node("Connectors/Exit") as Node3D
	var current_transform := temp_start.global_transform * start_exit.transform
	
	var start_bounds = temp_start.get_node("BoundsArea/CollisionShape3D") as CollisionShape3D
	if start_bounds and start_bounds.shape:
		var s_aabb = start_bounds.shape.get_debug_mesh().get_aabb() if start_bounds.shape.has_method("get_debug_mesh") else AABB(Vector3(-5,-5,-5), Vector3(10,10,10))
		placed_aabbs.append(s_aabb.abs())
	
	var last_room_position := temp_start.global_transform.origin
	temp_start.queue_free()

	# Main loop: sequentially calculate placement transforms for each room in the dungeon
	for i in range(1, room_count):
		var room_passed_rules := false
		var selected_room_scene: PackedScene = null
		var selected_temp_inst: Node3D = null
		var candidate_transform := Transform3D.IDENTITY
		var next_exit_transform := Transform3D.IDENTITY
		var global_aabb := AABB()
		
		# Attempt placement multiple times per room slot if overlaps occur
		for attempt in range(max_attempts_per_room):
			var must_be_straight := (forced_straight_count > 0)
			var room_scene: PackedScene = pick_room_for_director(i, must_be_straight)
			if room_scene == null: break
			
			var temp_inst = room_scene.instantiate() as Node3D
			var meta = temp_inst.get_node_or_null("Metadata")
			var tags: Array[String] = []
			if meta and "room_type" in meta:
				for t in meta.room_type: tags.append(t.to_lower())
			
			var is_straight := "straight" in tags or "corridor" in tags
			var bounds_area = temp_inst.get_node_or_null("BoundsArea/CollisionShape3D") as CollisionShape3D
			var exit_node = temp_inst.get_node_or_null("Connectors/Exit") as Node3D
			var entry_node = temp_inst.get_node_or_null("Connectors/Entry") as Node3D
			
			if not bounds_area or not exit_node or not entry_node:
				temp_inst.queue_free()
				continue
				
			var local_aabb: AABB = bounds_area.shape.get_debug_mesh().get_aabb() if bounds_area.shape and bounds_area.shape.has_method("get_debug_mesh") else AABB(Vector3(-2,-2,-2), Vector3(4,4,4))
			var entry_local_inv: Transform3D = entry_node.transform.inverse()
			candidate_transform = current_transform * entry_local_inv
			
			# Task: Check forward bias vector to prevent doubling back into prior space
			var movement_vector = candidate_transform.origin - last_room_position
			var forward_direction = current_transform.basis.z.normalized()
			if i > 1 and movement_vector.normalized().dot(forward_direction) < -0.2:
				temp_inst.queue_free()
				continue
			
			global_aabb = (candidate_transform * local_aabb).abs()
			
			# Task: Test candidate AABB against all existing placed rooms for collisions
			var has_overlapping := false
			for existing_aabb in placed_aabbs:
				if existing_aabb.intersects(global_aabb):
					has_overlapping = true
					break
			
			if has_overlapping:
				temp_inst.queue_free()
				continue
				
			next_exit_transform = candidate_transform * exit_node.transform
			
			# Task: Update straight-room buffer counters depending on chosen room type
			if not is_straight:
				forced_straight_count = required_straights_after_turn
			else:
				if forced_straight_count > 0: forced_straight_count -= 1
			
			selected_room_scene = room_scene
			selected_temp_inst = temp_inst
			room_passed_rules = true
			break
			
		if not room_passed_rules:
			print_rich("[color=yellow][ProceduralGen] Reached dead-end at room index %d. Stopping layout generation early.[/color]" % i)
			break
			
		# Task: Track the direction of the chosen turn for subsequent scoring cycles
		var meta = selected_temp_inst.get_node_or_null("Metadata")
		var selected_tags: Array[String] = []
		if meta and "room_type" in meta:
			for t in meta.room_type: selected_tags.append(t.to_lower())

		if "turn_left" in selected_tags or "left" in selected_tags: last_turn_direction = "left"
		elif "turn_right" in selected_tags or "right" in selected_tags: last_turn_direction = "right"

		last_room_position = candidate_transform.origin
		selected_temp_inst.queue_free()
		placed_aabbs.append(global_aabb)
		room_transforms.append(candidate_transform)
		room_scene_paths.append(selected_room_scene.resource_path)
		current_transform = next_exit_transform

	return { "paths": room_scene_paths, "transforms": room_transforms }


# ==============================================================================
# 6. INCREMENTAL INSTANTIATION & ENEMY POINT-BUY SYSTEM
# ==============================================================================
func instantiate_rooms_incrementally(paths: Array[String], transforms: Array[Transform3D]) -> void:
	for i in range(paths.size()):
		var scene = load(paths[i]) as PackedScene
		var room = scene.instantiate() as Node3D
		room.name = "Room_" + str(i + 1)
		room_container.add_child(room)
		room.global_transform = transforms[i]
		generated_rooms.append(room)
		
		# Task: Trigger enemy population logic per room layout step
		spawn_enemies_in_room(room, i)
		
		# Task: Yield execution every 3 rooms to prevent main thread stutter/freezes
		if i % 3 == 0:
			await get_tree().process_frame
			
	print_rich("[color=green][ProceduralGen] Successfully built %d total rooms instantly via AABB math![/color]" % generated_rooms.size())
	
	# Task: Output final telemetry report tracking total enemy spawn counts
	print_rich("[color=cyan]========================================[/color]")
	print_rich("[color=cyan][ProceduralGen] --- FINAL ENEMY SPAWN TALLY ---[/color]")
	if enemy_spawn_tallies.is_empty():
		print_rich("[color=yellow]No enemies were spawned across any rooms.[/color]")
	else:
		for enemy_type in enemy_spawn_tallies.keys():
			print_rich("[color=white]  • %s: [color=green]%d[/color] total spawned[/color]" % [enemy_type, enemy_spawn_tallies[enemy_type]])
	print_rich("[color=cyan]========================================[/color]")
	
	await get_tree().physics_frame


func spawn_enemies_in_room(room: Node3D, room_index: int) -> void:
	if room_index == 0: return # Keep starting room safe from enemies
		
	var spawns_node = room.get_node_or_null("SpawnPoints/enemy_spawns")
	if not spawns_node or enemy_pool.is_empty(): return
		
	# Task: Read room budget metadata or default to 40 points
	var meta = room.get_node_or_null("Metadata")
	var remaining_budget: int = meta.enemy_budget if meta and "enemy_budget" in meta else 40
	var markers = spawns_node.get_children()
	markers.shuffle()
	var spawned_count := 0
	
	# Loop through randomized markers to populate enemies under budget limitations
	for marker in markers:
		if not (marker is Marker3D or marker is Node3D): continue
		if remaining_budget <= 0: break
			
		# Task: Filter available enemy options that fit within the remaining point budget
		var affordable_enemies: Array = []
		for entry in enemy_pool:
			if entry["cost"] <= remaining_budget: affordable_enemies.append(entry)
		if affordable_enemies.is_empty(): break
			
		var scored_choices: Array = []
		var total_weight: float = 0.0
		
		# Task: Weight mid-tier units higher to create balanced enemy compositions
		for entry in affordable_enemies:
			var cost: float = entry["cost"]
			var weight: float = 4.0 if (cost >= 15 and cost <= 40) else 1.0
			scored_choices.append({ "entry": entry, "weight": weight })
			total_weight += weight
			
		# Task: Perform weighted random roll to pick the enemy configuration
		var pick := rng.randf() * total_weight
		var accum := 0.0
		var selected_enemy_data: Dictionary = affordable_enemies[0]
		
		for choice in scored_choices:
			accum += choice["weight"]
			if accum >= pick:
				selected_enemy_data = choice["entry"]
				break
				
		# Task: Instance chosen enemy, deduct cost, and update tallies
		# 5. Instantiate the chosen enemy locally (server) and command clients to replicate it
		var enemy_scene = selected_enemy_data["scene"] as PackedScene
		if enemy_scene:
			var enemy_path = enemy_scene.resource_path
			var enemy_name: String = enemy_path.get_file().get_basename()
			
			# Spawn locally on the server first
			var enemy = enemy_scene.instantiate() as Node3D
			room.add_child(enemy)
			enemy.global_transform = marker.global_transform
			
			# --- BROADCAST SPAWN TO ALL CONNECTED CLIENTS ---
			rpc("rpc_spawn_enemy_remote", room.name, enemy_path, marker.global_transform)
			
			if not enemy_spawn_tallies.has(enemy_name):
				enemy_spawn_tallies[enemy_name] = 0
			enemy_spawn_tallies[enemy_name] += 1
	
			remaining_budget -= selected_enemy_data["cost"]
			spawned_count += 1
			
	print_rich("[color=green][ProceduralGen] Room '%s': Spawned %d enemies using point-buy (Budget remaining: %d)[/color]" % [room.name, spawned_count, remaining_budget])


# ==============================================================================
# 7. MULTIPLAYER SYNCHRONIZATION (RPCs)
# ==============================================================================
@rpc("any_peer", "reliable")
func request_world_state(peer_id: int) -> void:
	if not multiplayer.is_server(): return

	print_rich("[color=cyan][ProceduralGen] Sending world state (%d rooms) to Peer ID: %d[/color]" % [generated_rooms.size(), peer_id])
	
	for room in generated_rooms:
		var scene_path := room.scene_file_path
		if scene_path.is_empty() and room.has_meta("scene_path"):
			scene_path = room.get_meta("scene_path")
			
		# 1. Sync the room layout first
		rpc_id(peer_id, "rpc_spawn_room_remote", scene_path, room.global_transform)
		
		# 2. Find and sync any enemies currently residing inside this room
		for child in room.get_children():
			# Check if the child is an enemy by verifying it has a scene file path
			if child is Node3D and not child.scene_file_path.is_empty():
				rpc_id(peer_id, "rpc_spawn_enemy_remote", room.name, child.scene_file_path, child.global_transform)

	rpc_id(peer_id, "remote_world_ready")


@rpc("authority", "call_remote", "reliable")
func rpc_spawn_room_remote(scene_path: String, room_transform: Transform3D) -> void:
	var room_scene := load(scene_path) as PackedScene
	if room_scene == null: return

	var room := room_scene.instantiate() as Node3D
	room.name = "Room_" + str(generated_rooms.size())
	room_container.add_child(room)
	room.global_transform = room_transform
	generated_rooms.append(room)


@rpc("authority", "call_remote", "reliable")
func rpc_spawn_enemy_remote(room_name: String, enemy_scene_path: String, enemy_transform: Transform3D) -> void:
	# Locate the matching target room node already built by the layout sync
	var room := room_container.get_node_or_null(room_name)
	if room == null:
		return
		
	var enemy_scene := load(enemy_scene_path) as PackedScene
	if enemy_scene == null:
		return
		
	# Instantiate and place the enemy on the client matching the server's layout
	var enemy := enemy_scene.instantiate() as Node3D
	room.add_child(enemy)
	enemy.global_transform = enemy_transform


@rpc("authority", "call_remote", "reliable")
func remote_world_ready() -> void:
	print_rich("[color=green][ProceduralGen] Remote client world state synchronization complete![/color]")
	emit_signal("world_ready")
