extends Node

signal world_ready

var level_generated := false
var rng := RandomNumberGenerator.new()
var all_rooms: Array[PackedScene] = []
var generated_rooms: Array[Node3D] = []

@export var room_count := 100
@export_flags_3d_physics var room_bounds_layer := 2
@export var max_attempts_per_room := 15
@export var max_backtracks := 20

@onready var room_container: Node3D = $"../RoomContainer"

# NOTE: Adjust this file path if your spawn room prefab is located elsewhere in your project directory
@export var start_room_scene: PackedScene = preload("res://assets/Rooms/Special/spawn_room_prefab1.tscn")


func _ready() -> void:
	print_rich("[color=cyan][ProceduralGen] Initializing generator. Is Server: %s[/color]" % multiplayer.is_server())
	set_process_input(true)

	if multiplayer.is_server():
		rng.randomize()
		load_room_prefabs()

		if validate_generator_setup():
			# 1. Spawn Room 0 and let physics/player spawner initialize safely
			await generate_spawn_room_first()
			
			# 2. Calculate the rest of the map layout via fast AABB math in memory
			var layout_data = generate_level_aabb_layout()
			
			# 3. Instantiate remaining rooms smoothly over multiple frames to avoid stutters
			await instantiate_rooms_incrementally(layout_data["paths"], layout_data["transforms"])
			
			level_generated = true
			emit_signal("world_ready")
		else:
			push_error("[ProceduralGen] Generator setup validation failed. Aborting generation.")
	else:
		rpc_id(1, "request_world_state", multiplayer.get_unique_id())


func validate_generator_setup() -> bool:
	print_rich("[color=yellow][ProceduralGen] Validating generator setup...[/color]")
	var is_valid := true

	if room_container == null:
		push_error("[ProceduralGen] Setup Error: 'room_container' node reference is missing.")
		is_valid = false

	if start_room_scene == null:
		push_warning("[ProceduralGen] Setup Warning: 'start_room_scene' is not set. Will fall back to picking random rooms.")

	if all_rooms.is_empty():
		push_error("[ProceduralGen] Setup Error: No room prefabs loaded in 'all_rooms'.")
		is_valid = false

	if is_valid:
		print_rich("[color=green][ProceduralGen] Setup validation passed successfully![/color]")
	return is_valid


func load_room_prefabs() -> void:
	all_rooms.clear()
	# NOTE: Adjust this folder path if your standard room prefabs are stored in a different directory
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
		push_warning("[ProceduralGen] Prefab Warning: '%s' is missing 'BoundsArea/CollisionShape3D' for overlap checks." % path)
		valid = false

	temp_inst.queue_free()
	return valid


func pick_room_for_director(room_index: int) -> PackedScene:
	if all_rooms.is_empty():
		push_error("[ProceduralGen] Selection Error: 'all_rooms' is empty.")
		return null

	var current_diff: float = AI_Director.dynamic_difficulty if Engine.has_singleton("AI_Director") else 0.2
	var pacing: int = AI_Director.current_pacing if Engine.has_singleton("AI_Director") else 0

	var scored_rooms: Array = []

	for room_scene in all_rooms:
		var inst := room_scene.instantiate() as Node3D
		var meta := inst.get_node_or_null("Metadata")

		var diff: float = meta.difficulty_weight if meta else 0.0
		var tags: Array[String] = []
		if meta:
			tags = meta.room_type
		var lower_tags: Array[String] = []
		for t in tags:
			lower_tags.append(t.to_lower())

		inst.queue_free()

		# --- BASE SCORE ---
		var score: float = 1.0

		# --- DIFFICULTY SCALING ---
		var diff_delta := diff - current_diff
		if diff_delta > 0.0:
			score *= max(0.1, 1.0 - diff_delta)

		# --- TAG WEIGHTING BASED ON PACING ---
		match pacing:
			AI_Director.PacingState.BUILDUP:
				if "straight" in lower_tags or "corridor" in lower_tags:
					score *= 2.0
				if "arena" in lower_tags:
					score *= 0.2
				if "safe" in lower_tags:
					score *= 0.5

			AI_Director.PacingState.PEAK:
				if "arena" in lower_tags:
					score *= 3.0
				if "straight" in lower_tags:
					score *= 0.5
				if "safe" in lower_tags:
					score *= 0.1

			AI_Director.PacingState.RELAX:
				if "safe" in lower_tags or "straight" in lower_tags:
					score *= 2.5
				if "arena" in lower_tags:
					score *= 0.1

		# --- ENSURE MINIMUM SCORE ---
		score = max(score, 0.05)

		scored_rooms.append({
			"scene": room_scene,
			"score": score
		})

	# --- WEIGHTED RANDOM SELECTION ---
	var total: float = 0.0
	for r in scored_rooms:
		total += r.score

	if total <= 0.0:
		return all_rooms[rng.randi() % all_rooms.size()]

	var pick := rng.randf() * total
	var accum := 0.0

	for r in scored_rooms:
		accum += r.score
		if accum >= pick:
			return r.scene

	return all_rooms[rng.randi() % all_rooms.size()]


func generate_spawn_room_first() -> void:
	var room := start_room_scene.instantiate() as Node3D
	room.name = "Room_0"
	room.global_transform = Transform3D.IDENTITY
	room_container.add_child(room)
	generated_rooms.append(room)
	
	# Give physics 2 frames to register the floor collision so the player spawns safely
	await get_tree().physics_frame
	await get_tree().physics_frame
	print_rich("[color=green][ProceduralGen] Spawn room loaded. Player can safely drop in.[/color]")


func generate_level_aabb_layout() -> Dictionary:
	print_rich("[color=cyan][ProceduralGen] --- Starting Fast AABB Layout Calculation ---[/color]")
	
	var placed_aabbs: Array[AABB] = []
	var room_transforms: Array[Transform3D] = []
	var room_scene_paths: Array[String] = []
	
	# Pre-calculate Room 0's exit transform to chain Room 1 properly from it
	var temp_start := start_room_scene.instantiate() as Node3D
	var start_exit := temp_start.get_node("Connectors/Exit") as Node3D
	var current_transform := temp_start.global_transform * start_exit.transform
	
	# Get Room 0's bounds AABB to block overlapping
	var start_bounds = temp_start.get_node("BoundsArea/CollisionShape3D") as CollisionShape3D
	if start_bounds and start_bounds.shape:
		var s_aabb = start_bounds.shape.get_debug_mesh().get_aabb() if start_bounds.shape.has_method("get_debug_mesh") else AABB(Vector3(-5,-5,-5), Vector3(10,10,10))
		placed_aabbs.append(s_aabb.abs())
	temp_start.queue_free()

	for i in range(1, room_count):
		var room_placed := false
		
		for attempt in range(max_attempts_per_room):
			var room_scene: PackedScene = pick_room_for_director(i)
			if room_scene == null: break
			
			var temp_inst = room_scene.instantiate() as Node3D
			var bounds_area = temp_inst.get_node_or_null("BoundsArea/CollisionShape3D") as CollisionShape3D
			var exit_node = temp_inst.get_node_or_null("Connectors/Exit") as Node3D
			var entry_node = temp_inst.get_node_or_null("Connectors/Entry") as Node3D
			
			if not bounds_area or not exit_node or not entry_node:
				temp_inst.queue_free()
				continue
				
			var local_aabb: AABB = bounds_area.shape.get_debug_mesh().get_aabb() if bounds_area.shape and bounds_area.shape.has_method("get_debug_mesh") else AABB(Vector3(-2,-2,-2), Vector3(4,4,4))
			
			var entry_local_inv: Transform3D = entry_node.transform.inverse()
			var candidate_transform: Transform3D = current_transform * entry_local_inv
			
			var global_aabb := local_aabb.abs()
			global_aabb.position += candidate_transform.origin
			
			var has_overlapping := false
			for existing_aabb in placed_aabbs:
				if existing_aabb.intersects(global_aabb):
					has_overlapping = true
					break
			
			if has_overlapping:
				temp_inst.queue_free()
				continue
				
			var next_exit_transform: Transform3D = candidate_transform * exit_node.transform
			temp_inst.queue_free()
			
			placed_aabbs.append(global_aabb)
			room_transforms.append(candidate_transform)
			room_scene_paths.append(room_scene.resource_path)
			
			current_transform = next_exit_transform
			room_placed = true
			break
			
		if not room_placed:
			print_rich("[color=yellow][ProceduralGen] Reached dead-end at room index %d. Stopping layout generation early.[/color]" % i)
			break

	return { "paths": room_scene_paths, "transforms": room_transforms }


func instantiate_rooms_incrementally(paths: Array[String], transforms: Array[Transform3D]) -> void:
	for i in range(paths.size()):
		var scene = load(paths[i]) as PackedScene
		var room = scene.instantiate() as Node3D
		room.name = "Room_" + str(i + 1)
		room_container.add_child(room)
		room.global_transform = transforms[i]
		generated_rooms.append(room)
		
		# Yield every 3 rooms to spread out instantiation work and avoid frame stuttering
		if i % 3 == 0:
			await get_tree().process_frame
			
	print_rich("[color=green][ProceduralGen] Successfully built %d total rooms instantly via AABB math![/color]" % generated_rooms.size())
	
	# Give physics a final frame to settle all newly added room colliders
	await get_tree().physics_frame


@rpc("any_peer", "reliable")
func request_world_state(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	print_rich("[color=cyan][ProceduralGen] Sending world state (%d rooms) to Peer ID: %d[/color]" % [generated_rooms.size(), peer_id])

	for room in generated_rooms:
		var scene_path := room.scene_file_path
		if scene_path.is_empty() and room.has_meta("scene_path"):
			scene_path = room.get_meta("scene_path")

		rpc_id(peer_id, "rpc_spawn_room_remote", scene_path, room.global_transform)

	rpc_id(peer_id, "remote_world_ready")


@rpc("authority", "call_remote", "reliable")
func rpc_spawn_room_remote(scene_path: String, room_transform: Transform3D) -> void:
	var room_scene := load(scene_path) as PackedScene
	if room_scene == null:
		return

	var room := room_scene.instantiate() as Node3D
	room.name = "Room_" + str(generated_rooms.size())
	room_container.add_child(room)

	room.global_transform = room_transform
	generated_rooms.append(room)


@rpc("authority", "call_remote", "reliable")
func remote_world_ready() -> void:
	print_rich("[color=green][ProceduralGen] Remote client world state synchronization complete![/color]")
	emit_signal("world_ready")
