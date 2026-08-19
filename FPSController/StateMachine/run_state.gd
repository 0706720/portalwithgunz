extends State
class_name RunState

var state_name := "Run"

# Networking flags
var is_server := false
var is_local_player := false

func enter(play_char_ref : CharacterBody3D):
	play_char = play_char_ref
	is_server = multiplayer.is_server()
	is_local_player = play_char.is_multiplayer_authority()

	verifications()
	print("Entered Run (server:", is_server, " local:", is_local_player, ")")

func verifications():
	# Example: ensure this state only runs on authority
	if not is_local_player:
		print("Non-authority entered RunState")
		pass

func physics_update(delta):
# CLIENT: read input + predict movement
	if is_local_player:
		input_management()
		applies(delta)
		move(delta)

		# Send input to server for validation
		rpc_id(1, "_server_receive_input", play_char.input_vector)

# SERVER: authoritative movement
	if is_server:
		applies(delta)
		move(delta)
		rpc("_client_sync_position", play_char.global_transform)

func applies(delta):
# apply forces, stamina drain, etc.
	pass

func input_management():
# local input only
	play_char.input_vector = Input.get_vector("left", "right", "forward", "backward")

func move(delta):
# movement logic
	pass

@rpc("any_peer")
func _server_receive_input(input_vec):
# server validates + applies movement
	play_char.input_vector = input_vec

@rpc("authority")
func _client_sync_position(server_transform):
# client corrects prediction drift
	play_char.global_transform = server_transform

#extends State
#
#class_name RunState
#
#var state_name : String = "Run"
#
#var play_char : CharacterBody3D
#
#func enter(play_char_ref : CharacterBody3D):
	##pass the play char refrence 
	#play_char = play_char_ref
	#verifications()
	#print("Entered Run")
#
#func verifications():
	#pass
#
#func physics_update(delta : float):
	#applies(delta)
	##play_char.gravity_apply(delta)
	#input_management()
	#move(delta)
#
#func applies(delta : float):
	#pass
#
#
#func input_management():
	#pass
#
#func move(delta : float):
	#pass
