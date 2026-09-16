extends Node

signal world_ready

var level_generated := false
var rng := RandomNumberGenerator.new()
var all_rooms: Array[PackedScene] = []
var generated_rooms: Array[Node3D] = []

@export var room_count := 5
@onready var room_container: Node3D = $"../RoomContainer"
@export var start_room_scene: PackedScene = preload("res://assets/Rooms/Special/spawn_room_prefab1.tscn")


func _ready() -> void:
	print("PG ready is server: ", multiplayer.is_server())
	set_process_input(true)

	if multiplayer.is_server():
		rng.randomize()
		load_room_prefabs()
		generate_level()
		level_generated = true
		await get_tree().process_frame
		emit_signal("world_ready")
	else:
		rpc_id(1, "request_world_state", multiplayer.get_unique_id())


func load_room_prefabs() -> void:
	var dir := DirAccess.open("res://assets/Rooms/")
	if dir == null:
		push_error("ERROR: rooms folder not found!")
		return

	all_rooms.clear()
	dir.list_dir_begin()

	var file := dir.get_next()
	while file != "":
		if file.ends_with(".tscn"):
			var scene := load("res://assets/Rooms/" + file)
			if scene:
				all_rooms.append(scene)
		file = dir.get_next()

	dir.list_dir_end()


func pick_room() -> PackedScene:
	if all_rooms.is_empty():
		return null

	var diff := 0.0
	if Engine.has_singleton("AI_Director"):
		diff = AI_Director.difficulty_score

	var candidates: Array[PackedScene] = []

	for room_scene in all_rooms:
		var inst := room_scene.instantiate() as Node3D
		var meta := inst.get_node_or_null("Metadata")
		if meta and "difficulty_weight" in meta and meta.difficulty_weight <= diff:
			candidates.append(room_scene)
		inst.queue_free()

	if candidates.is_empty():
		return all_rooms[rng.randi() % all_rooms.size()]

	return candidates[rng.randi() % candidates.size()]


func generate_level() -> void:
	var current_attach_position: Vector3 = Vector3.ZERO

	for i in range(room_count):
		var room_scene: PackedScene = start_room_scene if i == 0 and start_room_scene != null else pick_room()
		if room_scene == null:
			push_error("Room scene is null, aborting generation")
			return

		var room: Node3D = room_scene.instantiate() as Node3D
		room.name = "Room_" + str(i)
		room_container.add_child(room)
		generated_rooms.append(room)

		var entry: Node3D = room.get_node("Connectors/Entry") as Node3D
		var exit: Node3D = room.get_node("Connectors/Exit") as Node3D

		if entry == null or exit == null:
			push_error("Room " + room.name + " missing Connectors/Entry or Connectors/Exit")
			continue

		# 1. Use LOCAL entry position to place room
		var entry_local: Vector3 = entry.position
		room.global_position = current_attach_position - entry_local

		# 2. Update transforms so exit.global_position is valid
		room.force_update_transform()

		# 3. Next attach point = exit in world space
		current_attach_position = exit.global_position

		print("Spawned room #", i, " at ", room.global_position)


@rpc("any_peer", "reliable")
func request_world_state(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	for room in generated_rooms:
		var scene_path := room.scene_file_path
		if scene_path.is_empty() and room.has_meta("scene_path"):
			scene_path = room.get_meta("scene_path")

		rpc_id(peer_id, "rpc_spawn_room_remote", scene_path, room.global_transform.origin)

	rpc_id(peer_id, "remote_world_ready")


@rpc("authority", "call_remote", "reliable")
func rpc_spawn_room_remote(scene_path: String, position: Vector3) -> void:
	var room_scene := load(scene_path) as PackedScene
	if room_scene == null:
		return

	var room := room_scene.instantiate() as Node3D
	room.name = "Room_" + str(generated_rooms.size())
	room.global_transform.origin = position
	room_container.add_child(room)
	generated_rooms.append(room)


@rpc("authority", "call_remote", "reliable")
func remote_world_ready() -> void:
	emit_signal("world_ready")
