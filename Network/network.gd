extends Node

@rpc("authority")
func server_receive_input(peer_id: int, input_dir: Vector2, wish: Vector3):
	var player = Global.players.get(peer_id)
	if player:
		player.input_direction = input_dir
		player.wish_dir = wish
