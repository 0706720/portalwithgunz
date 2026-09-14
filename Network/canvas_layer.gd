extends CanvasLayer

const PORT := 9000
const SERVER_IP := "127.0.0.1"

func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)

func _on_host_button_pressed() -> void:
	print("HOST pressed")

	if multiplayer and multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null

	await get_tree().process_frame

	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT)
	print("Host create_server error code:", err)

	if err != OK:
		push_error("Failed to host. Port may be in use.")
		return

	multiplayer.multiplayer_peer = peer

	await get_tree().process_frame
	print("Switching to WorldRoot as HOST")
	get_tree().change_scene_to_file("res://world_root.tscn")

func _on_join_button_pressed() -> void:
	print("JOIN pressed")
	if multiplayer and multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()

	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(SERVER_IP, PORT)
	if err != OK:
		push_error("Failed to join.")
		return

	multiplayer.multiplayer_peer = peer

func _on_connected_to_server() -> void:
	print("Client connected! ID:", multiplayer.get_unique_id())
	get_tree().change_scene_to_file("res://world_root.tscn")

func _on_peer_connected(id: int) -> void:
	print("Peer connected:", id)
	if is_inside_tree() and multiplayer and multiplayer.is_server():
		print("Server detected peer connected:", id)

func _on_peer_disconnected(id: int) -> void:
	print("Peer disconnected:", id)
