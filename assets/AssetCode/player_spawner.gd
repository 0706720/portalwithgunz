extends Node

@export var player_scene: PackedScene = preload("res://FPSController/Player/player.tscn")

func spawn_player(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	var scene_root = get_tree().current_scene
	if scene_root.has_node(str(peer_id)):
		return

	var player = player_scene.instantiate()
	player.name = str(peer_id)
	player.set_multiplayer_authority(peer_id)

	var spawn_point = scene_root.get_node_or_null("SpawnPoint") as Node3D
	if spawn_point:
		player.global_transform.origin = spawn_point.global_transform.origin + Vector3(0, 2.0, 0)
	else:
		player.global_transform.origin = Vector3(0, 5.0, 0)

	scene_root.add_child(player, true)

@rpc("any_peer", "call_local", "reliable")
func request_spawn(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	# 1. Spawn the newly joining player
	spawn_player(peer_id)

	# 2. Tell the newly joined client to spawn all players that ALREADY exist on the server
	var scene_root = get_tree().current_scene
	for child in scene_root.get_children():
		if child is PlayerCharacter and child.name != str(peer_id):
			var existing_peer_id := child.name.to_int()
			# Force the new client to spawn the existing player locally
			rpc_id(peer_id, "rpc_force_spawn_existing", existing_peer_id, child.global_transform)

@rpc("authority", "reliable")
func rpc_force_spawn_existing(existing_peer_id: int, initial_transform: Transform3D) -> void:
	var scene_root = get_tree().current_scene
	if scene_root.has_node(str(existing_peer_id)):
		return

	var player = player_scene.instantiate()
	player.name = str(existing_peer_id)
	player.set_multiplayer_authority(existing_peer_id)
	player.global_transform = initial_transform
	scene_root.add_child(player, true)
