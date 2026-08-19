extends State
class_name InairState

var state_name := "Inair"
var play_char : CharacterBody3D

# Multiplayer flags
var is_server := false
var is_local_player := false

func enter(play_char_ref : CharacterBody3D):
	play_char = play_char_ref

	is_server = multiplayer.is_server()
	is_local_player = play_char.is_multiplayer_authority()

	verifications()
	print("Entered Inair (server:", is_server, " local:", is_local_player, ")")

func verifications():
	play_char.move_speed = play_char.air_speed
	play_char.move_accel = play_char.walk_accel
	play_char.move_deccel = play_char.walk_deccel

func physics_update(delta):
	# CLIENT: prediction
	if is_local_player:
		input_management()
		applies(delta)
		play_char.gravity_apply(delta)

		# ensure wish_dir exists BEFORE physics
		if play_char.move_direction:
			play_char.wish_dir = play_char.move_direction
		else:
			play_char.wish_dir = Vector3.ZERO

		move(delta)

		# send input to server
		rpc_id(1, "_server_receive_input", play_char.input_direction, play_char.wish_dir)

	# SERVER: authoritative movement
	if is_server:
		applies(delta)
		play_char.gravity_apply(delta)

		if play_char.move_direction:
			play_char.wish_dir = play_char.move_direction
		else:
			play_char.wish_dir = Vector3.ZERO

		move(delta)

		# sync transform to clients
		rpc("_client_sync_transform", play_char.global_transform)

func applies(delta):
	# landing transition
	if play_char.is_on_floor():
		if play_char.move_direction:
			transitioned.emit(self, play_char.walk_or_run)
		else:
			transitioned.emit(self, "IdleState")

func input_management():
	# in-air input goes here if needed
	pass

func move(delta):
	# air acceleration logic
	var cur_speed_in_wish_dir = play_char.velocity.dot(play_char.wish_dir)

	var capped_speed = min(
		(play_char.air_speed * play_char.wish_dir).length(),
		play_char.air_cap
	)

	var add_speed_till_cap = capped_speed - cur_speed_in_wish_dir

	if add_speed_till_cap > 0:
		var accel_speed = play_char.air_accel * play_char.air_speed * delta
		accel_speed = min(accel_speed, add_speed_till_cap)
		play_char.velocity += accel_speed * play_char.wish_dir

# -------------------------
# RPC SYNC HOOKS
# -------------------------

@rpc("any_peer")
func _server_receive_input(input_dir, wish_dir):
	play_char.input_direction = input_dir
	play_char.wish_dir = wish_dir

@rpc("authority")
func _client_sync_transform(server_transform):
	play_char.global_transform = server_transform

#extends State
#
#class_name InairState
#
#var state_name : String = "Inair"
#
#var play_char : CharacterBody3D
#
#func enter(play_char_ref : CharacterBody3D):
	##pass the play char refrence 
	#play_char = play_char_ref
	#
	#verifications()
	#
	#print("Entered Inair")
#func verifications():
	#play_char.move_speed = play_char.air_speed
	#play_char.move_accel = play_char.walk_accel
	#play_char.move_deccel = play_char.walk_deccel
#
#func physics_update(delta : float):
	#if is_multiplayer_authority():
		#applies(delta)
		#
		#play_char.gravity_apply(delta)
		#
		#input_management()
		#
		#move(delta)
	#else:
		#pass
#
#func applies(delta : float):
	#if play_char.is_on_floor():
		#if play_char.move_direction: transitioned.emit(self, play_char.walk_or_run)
		#else: transitioned.emit(self, "IdleState")
#
#func input_management():
	#pass
#
#func move(delta : float):
	##play_char.velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	#
	#var cur_speed_in_wish_dir = play_char.velocity.dot(play_char.wish_dir)
	#var capped_speed = min((play_char.air_speed * play_char.wish_dir).length(), play_char.air_cap)
	#var add_speed_till_cap = capped_speed - cur_speed_in_wish_dir
	#if add_speed_till_cap > 0:
		#var accel_speed = play_char.air_accel * play_char.air_speed * delta
		#accel_speed = min(accel_speed, add_speed_till_cap)
		#play_char.velocity += accel_speed * play_char.wish_dir
