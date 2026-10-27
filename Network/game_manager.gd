extends Node

const MAIN_MENU_SCENE: String = "res://assets/models/start_menu.tscn"

# Stores peer_id: Player node reference
var registered_players: Dictionary = {}

func _ready() -> void:
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)

func register_player(peer_id: int, player_node: Node) -> void:
	if not multiplayer.is_server():
		return
		
	registered_players[peer_id] = player_node
	print("[GameManager] Registered player: ", peer_id, " | All current players: ", registered_players.keys())
	print("[GameManager] Total alive count: ", registered_players.size())

func on_player_death(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
		
	if registered_players.has(peer_id):
		var player_node = registered_players[peer_id]
		if player_node and player_node.has_method("handle_local_death"):
			player_node.rpc("handle_local_death")
			
		registered_players.erase(peer_id)
		
		if registered_players.size() <= 0:
			print("[GameManager] All players eliminated! Forcing all peers to menu...")
			
			# Call it locally on the server first
			client_return_to_main_menu()
			
			# Explicitly command all connected clients to run it too
			for id in multiplayer.get_peers():
				rpc_id(id, "client_return_to_main_menu")

@rpc("any_peer", "call_local", "reliable")
func client_return_to_main_menu() -> void:
	print("[GameManager] Returning to main menu. Cleaning up active UI...")
	
	# 1. Force-free any active death screen instances
	var current_scene = get_tree().current_scene
	if current_scene:
		for child in current_scene.get_children():
			if "DeathScreen" in child.name:
				child.queue_free()

	# 2. Reset tracking and unlock mouse
	registered_players.clear()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# 3. Change scene safely
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)
	
	# 4. Wait a moment for network packets to flush before tearing down the peer
	call_deferred("_teardown_network")

func _teardown_network() -> void:
	# Wait 1.0 seconds so clients have time to process the scene change command
	await get_tree().create_timer(1.0).timeout
	
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
		print("[GameManager] Network peer successfully closed after packet buffer.")

func _on_peer_disconnected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return
		
	if registered_players.has(peer_id):
		registered_players.erase(peer_id)
		print("[GameManager] Player disconnected. Remaining alive: ", registered_players.size())
		
		if registered_players.size() <= 0:
			rpc("client_return_to_main_menu")
