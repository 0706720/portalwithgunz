extends Node

signal world_ready

var level_generated := false
var rng := RandomNumberGenerator.new()
var all_rooms: Array[PackedScene] = []
var generated_rooms: Array[Node3D] = []

@export var room_count := 100
@export_flags_3d_physics var room_bounds_layer := 2
@export var max_attempts_per_room := 30
@export var max_backtracks := 50

@onready var room_container: Node3D = $"../RoomContainer"
@export var start_room_scene: PackedScene = preload("res://assets/Rooms/Special/spawn_room_prefab1.tscn")


func _ready() -> void:
	print_rich("[color=cyan][ProceduralGen] Initializing generator. Is Server: %s[/color]" % multiplayer.is_server())
	set_process_input(true)

	if multiplayer.is_server():
		rng.randomize()
		load_room_prefabs()

		if validate_generator_setup():
			await generate_level()
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
	var pacing_state = AI_Director.current_pacing if Engine.has_singleton("AI_Director") else 0

	var candidate_pool: Array[PackedScene] = []

	for room_scene in all_rooms:
		var inst := room_scene.instantiate() as Node3D
		var meta := inst.get_node_or_null("Metadata")

		var room_diff: float = meta.difficulty_weight if meta and "difficulty_weight" in meta else 0.0
		var is_straight: bool = meta.has_type("straight") if meta and meta.has_method("has_type") else ("straight" in room_scene.resource_path.to_lower())
		var is_safe: bool = meta.has_type("safe") if meta and meta.has_method("has_type") else false
		var is_arena: bool = meta.has_type("arena") if meta and meta.has_method("has_type") else false

		inst.queue_free()

		if room_diff <= current_diff:
			match pacing_state:
				2: # RELAX
					if is_straight or is_safe:
						candidate_pool.append(room_scene)
				1: # PEAK
					if is_arena:
						candidate_pool.append(room_scene)
				_: # BUILDUP
					candidate_pool.append(room_scene)

	if candidate_pool.is_empty():
		return all_rooms[rng.randi() % all_rooms.size()]

	return candidate_pool[rng.randi() % candidate_pool.size()]


func generate_level() -> void:
	print_rich("[color=cyan][ProceduralGen] --- Starting Async Generation Target: %d Rooms ---[/color]" % room_count)
	
	var occupied_grid_cells: Dictionary = {}
	var transform_history: Array[Transform3D] = []
	var total_overlaps_rejected := 0
	var backtracks_used := 0
	var connector_flip := Basis(Vector3.UP, PI)

	while generated_rooms.size() < room_count:
		var i := generated_rooms.size()
		var room_placed := false
		var current_attach_transform: Transform3D = transform_history.back() if not transform_history.is_empty() else Transform3D.IDENTITY

		for attempt in range(max_attempts_per_room):
			var room_scene: PackedScene = start_room_scene if i == 0 and start_room_scene != null else pick_room_for_director(i)
			if room_scene == null:
				push_error("[ProceduralGen] Generation Aborted: Null room scene encountered at index %d." % i)
				return

			var room: Node3D = room_scene.instantiate() as Node3D
			room.name = "Room_" + str(i)
			room.set_meta("scene_path", room_scene.resource_path)

			# Reset transforms to avoid inherited scaling
			room.scale = Vector3.ONE

			room_container.add_child(room)

			var entry: Node3D = room.get_node_or_null("Connectors/Entry") as Node3D
			var exit: Node3D = room.get_node_or_null("Connectors/Exit") as Node3D

			if entry == null or exit == null:
				push_error("[ProceduralGen] Room #%d missing required connector nodes." % i)
				room.queue_free()
				break

			if i == 0:
				room.global_transform = Transform3D.IDENTITY
			else:
				var exit_global := current_attach_transform
				var entry_local_inv := entry.transform.inverse()
				
				room.global_transform = exit_global * entry_local_inv

			# Force update transform directly on the Node3D
			room.force_update_transform()

			var grid_pos := Vector3i(room.global_transform.origin.round())
			if occupied_grid_cells.has(grid_pos):
				total_overlaps_rejected += 1
				room.queue_free()
				continue

			var bounds_area : Area3D = room.get_node_or_null("BoundsArea")
			var collision_shape : CollisionShape3D = bounds_area.get_node_or_null("CollisionShape3D") if bounds_area else null
			if bounds_area and collision_shape:
				collision_shape.shape = collision_shape.shape.duplicate()
				bounds_area.scale = Vector3.ONE
				collision_shape.scale = Vector3.ONE
				bounds_area.force_update_transform()
				collision_shape.force_update_transform()

			await get_tree().process_frame
			await get_tree().process_frame   # Ensures physics shapes update

			if i > 0 and is_room_overlapping(room):
				total_overlaps_rejected += 1
				print_rich("[color=red][ProceduralGen] Overlap detected at Room #%d. Rejecting...[/color]" % i)
				room.queue_free()
				continue

			occupied_grid_cells[grid_pos] = true

			var connectors_node := room.get_node_or_null("Connectors") as Node3D
			if connectors_node:
				connectors_node.force_update_transform()
			exit.force_update_transform()

			# --- DEBUG PRINTS ---
			print_rich("[color=magenta]DEBUG -> Exit Parent: %s | Exit Direct Local Position: %s[/color]" % [exit.get_parent().name, exit.position])
			# --------------------

			# Bypass tree propagation lag by multiplying the room's global transform by the exit's local transform
			var exit_world_transform: Transform3D = room.global_transform * exit.transform
			print_rich("[color=yellow]Exit World Position for Room #%d: %s[/color]" % [i, exit_world_transform.origin])
			generated_rooms.append(room)
			print_rich("[color=cyan]Room #%d -> Exit Local Pos: %s | Exit Global Pos: %s[/color]" % [i, exit.position, exit_world_transform.origin])
			transform_history.append(exit_world_transform)

			room_placed = true
			print_rich("[color=green][ProceduralGen] Placed Room #%d at %s[/color]" % [i, room.global_transform.origin])
			break

		if not room_placed:
			if generated_rooms.size() > 0 and backtracks_used < max_backtracks:
				backtracks_used += 1
				var last_room := generated_rooms.pop_back() as Node3D
				if is_instance_valid(last_room):
					var last_grid_pos := Vector3i(last_room.global_transform.origin.round())
					occupied_grid_cells.erase(last_grid_pos)
					last_room.queue_free()
				if transform_history.size() > 0:
					transform_history.pop_back()
			else:
				push_error("[ProceduralGen] Deadlock reached at %d rooms." % generated_rooms.size())
				break


func is_room_overlapping(room: Node3D) -> bool:
	var bounds_area := room.get_node("BoundsArea") as Area3D
	var collision_shape := bounds_area.get_node("CollisionShape3D") as CollisionShape3D

	var space_state := room.get_world_3d().direct_space_state
	var query := PhysicsShapeQueryParameters3D.new()

	query.shape = collision_shape.shape
	query.transform = collision_shape.global_transform
	query.collision_mask = room_bounds_layer
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var results := space_state.intersect_shape(query, 32)
	var parent_room: Node3D = generated_rooms.back() if not generated_rooms.is_empty() else null
	var spawn_room: Node3D = generated_rooms[0] if not generated_rooms.is_empty() else null

	for result in results:
		var collider : Area3D = result["collider"] as Area3D
		if collider and collider != bounds_area:
			var parent : Node3D = collider.get_parent() as Node3D
			
			# Ignore the immediate parent room and the spawn room (Room_0)
			if parent == parent_room or parent == spawn_room:
				continue
				
			if generated_rooms.has(parent):
				return true

	return false


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
