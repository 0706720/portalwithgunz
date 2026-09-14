extends Node

func _ready() -> void:
	print("WorldRoot _ready on peer:", multiplayer.get_unique_id(), "is_server:", multiplayer.is_server())
	get_node("ProceduralGenerator").world_ready.connect(_on_world_ready)

func _on_world_ready() -> void:
	await get_tree().physics_frame
	
	if multiplayer.is_server():
		print("Server spawning host player")
		$PlayerSpawner.spawn_player(1)
	else:
		var my_id := multiplayer.get_unique_id()
		print("Client requesting spawn for:", my_id)
		$PlayerSpawner.rpc_id(1, "request_spawn", my_id)
