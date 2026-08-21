extends Node

# the script that will be evaluated for inconsistency, which will be Player due to it's importance in the game
const CRITICAL_SCRIPT_PATH: String = "res://scenes/Player.gd"
const MULTIPLAYER_HANDLER_SCRIPT: String = "res://assets/AssetCode/world.gd"

var verified_peers: Dictionary = {}

func _ready() -> void:
	if multiplayer.is_server():
		print('prior check')
		multiplayer.peer_connected.connect(_on_peer_connected)
		print('connected to signal from anticheat')

func _on_peer_connected(peer_id: int) -> void:
	var challenge_nonce = str(randi()) + "_" + str(Time.get_unix_time_from_system())
	verified_peers[peer_id] = {"verified": false, "nonce": challenge_nonce}
	
	rpc_id(peer_id, "request_integrity_proof", challenge_nonce)

@rpc("authority", "call_remote", "reliable")
func request_integrity_proof(nonce: String) -> void:
	var script_bytes = FileAccess.get_file_as_bytes(CRITICAL_SCRIPT_PATH)
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(script_bytes)
	ctx.update(nonce.to_utf8_buffer())
	var response_hash = "%x" % ctx.finish()
	
	rpc_id(1, "submit_integrity_proof", response_hash)

@rpc("any_peer", "call_remote", "reliable")
func submit_integrity_proof(client_hash: String) -> void:
	if not multiplayer.is_server(): return
	var sender_id = multiplayer.get_remote_sender_id()
	
	if not verified_peers.has(sender_id): return
	var nonce = verified_peers[sender_id]["nonce"]
	
	var expected_bytes = FileAccess.get_file_as_bytes(CRITICAL_SCRIPT_PATH)
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(expected_bytes)
	ctx.update(nonce.to_utf8_buffer())
	# there is no to_hex() function in godot.The solution is to use a shorthand to achieve the same result
	# https://docs.godotengine.org/en/stable/classes/class_hashingcontext.html
	# https://www.reddit.com/r/godot/comments/15dvc7o/how_to_print_hexadecimal_numbers_or_display_a_hex/
	var expected_hash = "%x" % ctx.finish()
	
	if client_hash == expected_hash:
		print("[ANTI-CHEAT] Peer ", sender_id, " PASSED verification.")
		verified_peers[sender_id]["verified"] = true
		get_parent()._spawn_player(sender_id)
	else:
		printerr("[ANTI-CHEAT] Peer ", sender_id, " FAILED integrity check! Disconnecting...")
		multiplayer.multiplayer_peer.disconnect_peer(sender_id)

#@rpc("authority", "call_remote", "reliable")
#func submit_integrity_proof(_client_hash: String) -> void: pass
