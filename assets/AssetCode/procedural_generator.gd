extends Node

signal world_ready

var level_generated: bool = false
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var all_rooms: Array[PackedScene] = []
var generated_rooms: Array[Node3D] = []
@export var room_count: int = 5

@onready var room_container: Node3D = $"../RoomContainer"

@export var start_room_scene: PackedScene = preload("res://assets/Rooms/Special/spawn_room_prefab1.tscn")

func _ready() -> void:
	print("PG ready is server: ", multiplayer.is_server())
	set_process_input(true)

	if multiplayer.is_server():
		rng.randomize()
		var world_seed: int = rng.seed
		load_room_prefabs()
		generate_level()
		level_generated = true
		await get_tree().process_frame
		emit_signal("world_ready")
	else:
		# Ask the server for the existing world layout and seed state
		rpc_id(1, "request_world_state", multiplayer.get_unique_id())

func load_room_prefabs() -> void:
	print("Loading rooms from res://assets/Rooms/")
	var dir := DirAccess.open("res://assets/Rooms/")
	if dir == null:
		push_error("ERROR: rooms folder not found!")
		return

	all_rooms.clear()
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tscn"):
			var scene: PackedScene = load("res://assets/Rooms/" + file_name)
			if scene:
				print("Loaded room prefab:", file_name)
				all_rooms.append(scene)
			else:
				push_warning("Failed to load room prefab: " + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()

	print("Total rooms loaded:", all_rooms.size())

func pick_room() -> PackedScene:
	if all_rooms.is_empty():
		push_error("No rooms loaded!")
		return null

	var diff: float = 0.0
	if Engine.has_singleton("AI_Director") or get_node_or_null("/root/AI_Director") != null:
		diff = AI_Director.difficulty_score

	var candidates: Array[PackedScene] = []

	for room_scene in all_rooms:
		var inst: Node3D = room_scene.instantiate() as Node3D
		var meta := inst.get_node_or_null("Metadata")
		if meta and "difficulty_weight" in meta and meta.difficulty_weight <= diff:
			candidates.append(room_scene)
		inst.queue_free()

	if candidates.is_empty():
		return all_rooms[rng.randi() % all_rooms.size()]

	return candidates[rng.randi() % candidates.size()]

func get_room_length(room: Node3D) -> float:
	var total_aabb := AABB()
	var found_mesh := false

	# Recursively calculate the combined bounding box of all meshes in the room
	for child in room.find_children("*", "VisualInstance3D", true, false):
		if child is VisualInstance3D:
			var child_aabb: AABB = child.get_aabb()
			# Transform local mesh bounds to room space
			var local_transform: Transform3D = room.global_transform.affine_inverse() * child.global_transform
			child_aabb = local_transform * child_aabb
			
			if not found_mesh:
				total_aabb = child_aabb
				found_mesh = true
			else:
				total_aabb = total_aabb.merge(child_aabb)

	if found_mesh:
		return total_aabb.size.x
	
	# Fallback distance if no mesh geometry is found
	return 100.0

func generate_level() -> void:
	var current_attach_position := Vector3.ZERO

	for i in range(room_count):
		var room_scene: PackedScene
		
		if i == 0 and start_room_scene != null:
			room_scene = start_room_scene
		else:
			room_scene = pick_room()

		if room_scene == null:
			return

		var room: Node3D = room_scene.instantiate() as Node3D
		room.name = "Room_" + str(i)
		
		# Add room to container
		room_container.add_child(room)
		generated_rooms.append(room)

		var entry_marker := room.find_child("Entry", true, false) as Node3D
		var exit_marker := room.find_child("Exit", true, false) as Node3D

		# 1. Snap room's Entry position directly to the current attachment point
		if entry_marker:
			var entry_local_pos := entry_marker.position
			room.global_position = current_attach_position - entry_local_pos
		else:
			room.global_position = current_attach_position

		# Force Godot to calculate updated node positions immediately
		room.force_update_transform()

		# 2. Store the Exit marker's global position as the attachment point for the NEXT room
		if exit_marker:
			current_attach_position = exit_marker.global_position
		else:
			current_attach_position += Vector3(100.0, 0.0, 0.0)

		print("Spawned room #", i, " [", room.name, "] at ", room.global_position)

@rpc("any_peer", "reliable")
func request_world_state(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
	
	# Send each generated room to late-joining clients
	for room in generated_rooms:
		var scene_path: String = room.scene_file_path
		if scene_path.is_empty() and room.has_meta("scene_path"):
			scene_path = room.get_meta("scene_path")

		rpc_id(peer_id, "rpc_spawn_room_remote", scene_path, room.global_transform.origin)

	# Notify client that map synchronization is finished
	rpc_id(peer_id, "remote_world_ready")

@rpc("authority", "call_remote", "reliable")
func rpc_spawn_room_remote(scene_path: String, position: Vector3) -> void:
	if scene_path.is_empty():
		push_error("Received empty room scene path on client!")
		return

	var room_scene: PackedScene = load(scene_path) as PackedScene
	if room_scene == null:
		push_error("Failed to load room scene on client: " + scene_path)
		return

	var room: Node3D = room_scene.instantiate() as Node3D
	room.name = "Room_" + str(generated_rooms.size())
	room.global_transform.origin = position
	room_container.add_child(room)
	generated_rooms.append(room)

	print("Client spawned room instance #", generated_rooms.size(), " [", room.name, "] at ", position)

@rpc("authority", "call_remote", "reliable")
func remote_world_ready() -> void:
	print("Client received remote_world_ready signal from host")
	emit_signal("world_ready")
