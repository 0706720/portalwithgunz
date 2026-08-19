extends State
class_name IdleState

var state_name := "Idle"
var play_char : CharacterBody3D

# Multiplayer flags
var is_server := false
var is_local_player := false

func enter(play_char_ref : CharacterBody3D):
	play_char = play_char_ref

	is_server = multiplayer.is_server()
	is_local_player = play_char.is_multiplayer_authority()

	verifications()
	print("Entered Idle (server:", is_server, " local:", is_local_player, ")")

func verifications():
	pass


func physics_update(delta):
# CLIENT: input + prediction
	if is_local_player:
		input_management()
		applies(delta)
		play_char.gravity_apply(delta)
		_handle_ground_physics(delta)
		move(delta)

	# Send input to server for validation
	rpc_id(1, "_server_receive_input", play_char.input_direction, play_char.wish_dir)

# SERVER: authoritative movement
	if is_server:
		applies(delta)
		play_char.gravity_apply(delta)
		_handle_ground_physics(delta)
		move(delta)

	# Sync transform to all clients
	rpc("_client_sync_transform", play_char.global_transform)


func applies(delta):
# Your original airborne transition
	if play_char.velocity.y < 0.0 and !play_char.is_on_floor():
		transitioned.emit(self, "InairState")


func input_management():
# Toggle crouch
	if Input.is_action_just_pressed(play_char.crouch_action):
		transitioned.emit(self, "CrouchState")

# Toggle walk/run
	if Input.is_action_just_pressed(play_char.run_action):
		if play_char.walk_or_run == "WalkState":
			play_char.walk_or_run = "RunState"
		elif play_char.walk_or_run == "RunState":
			play_char.walk_or_run = "WalkState"

# Spin dash
	if play_char.is_on_floor():
		if Input.is_action_just_pressed("spin_dash"):
			transitioned.emit(self, "SpindashState")


func get_move_speed():
	var sprint = play_char.sprint_speed if play_char.sprint_speed != null else 0.0
	var walk = play_char.walk_speed if play_char.walk_speed != null else 0.0

	if Input.is_action_just_pressed("sprint"):
		return play_char.sprint_speed
	return play_char.walk_speed


func _handle_ground_physics(delta):
	if play_char == null:
		print("ERROR: play_char is NULL")
		return

	if play_char.velocity == null:
		print("ERROR: velocity is NULL")
		return

	if play_char.wish_dir == null:
		print("ERROR: wish_dir is NULL")
		return

	if play_char.ground_accel == null:
		print("ERROR: ground_accel is NULL")
		return

	if play_char.walk_speed == null:
		print("ERROR: walk_speed is NULL")
		return

	if play_char.sprint_speed == null:
		print("ERROR: sprint_speed is NULL")
		return

	if delta == null:
		print("ERROR: delta is NULL")
		return

	var cur_speed_in_wish_dir = play_char.velocity.dot(play_char.wish_dir)
	var add_speed_till_cap = get_move_speed() - cur_speed_in_wish_dir

	if add_speed_till_cap > 0:
		var accel_speed = play_char.ground_accel * delta * get_move_speed()
		accel_speed = min(accel_speed, add_speed_till_cap)
		play_char.velocity += accel_speed * play_char.wish_dir


func move(delta):
# Input direction
	play_char.wish_dir = play_char.move_direction if play_char.move_direction != null else Vector3.ZERO

	play_char.input_direction = Input.get_vector(
		play_char.move_left_action,
		play_char.move_right_action,
		play_char.move_forward_action,
		play_char.move_backward_action
)

# Move direction
	play_char.move_direction = (
		play_char.cam_holder.global_basis *
		Vector3(play_char.input_direction.x, 0.0, play_char.input_direction.y)
).normalized()

# State transitions
	if play_char.move_direction and play_char.is_on_floor():
		transitioned.emit(self, play_char.walk_or_run)
	elif play_char.velocity.x or play_char.velocity.z or play_char.velocity.y > 0:
		transitioned.emit(self, play_char.walk_or_run)


# -------------------------
# RPC SYNC HOOKS
# -------------------------

@rpc("any_peer")
func _server_receive_input(input_dir, wish_dir):
# Server validates input
	play_char.input_direction = input_dir
	play_char.wish_dir = wish_dir


@rpc("authority")
func _client_sync_transform(server_transform):
# Client corrects prediction drift
	play_char.global_transform = server_transform

#extends State
#
#class_name IdleState
#
#var state_name : String = "Idle"
#
#var play_char : CharacterBody3D
#
#func enter(play_char_ref : CharacterBody3D):
	##pass the play char refrence 
	#play_char = play_char_ref
	#
	#verifications()
	#
	#print("Entered Idle")
#
#func verifications():
	#pass
#
#func physics_update(delta : float):
	#if is_multiplayer_authority():
		#applies(delta)
		#
		#play_char.gravity_apply(delta)
		#
		#input_management()
		#
		#_handle_ground_physics(delta)
		#
		#move(delta)
	#else:
		#pass
#
#func applies(delta : float):
	#if play_char.velocity.y < 0.0: 
		#transitioned.emit(self, "InairState")
#
#func input_management():
	#if Input.is_action_just_pressed(play_char.crouch_action):
		#transitioned.emit(self, "CrouchState")
		#
	#if Input.is_action_just_pressed(play_char.run_action):
		#if play_char.walk_or_run == "WalkState": play_char.walk_or_run = "RunState"
		#elif play_char.walk_or_run == "RunState": play_char.walk_or_run = "WalkState"
	#
	#if play_char.is_on_floor():
		#if Input.is_action_just_pressed("spin_dash"):
			#transitioned.emit(self, "SpindashState")
#
#func get_move_speed():
	#if Input.is_action_just_pressed("sprint"):
		#return play_char.sprint_speed 
	#else:
		#return play_char.walk_speed
#
#func _handle_ground_physics(delta):
## simmilar to the air movement. Acceleration and friction on ground.
	#var cur_speed_in_wish_dir = play_char.velocity.dot(play_char.wish_dir)
	#var add_speed_till_cap = get_move_speed() - cur_speed_in_wish_dir
	#if add_speed_till_cap > 0:
		#var accel_speed = play_char.ground_accel * delta * get_move_speed()
		#accel_speed = min(accel_speed, add_speed_till_cap)
		#play_char.velocity += accel_speed * play_char.wish_dir
#
	## apply friction
	##var control = max(play_char.velocity.length(), play_char.ground_deccel)
	##var drop = control * play_char.ground_friction * delta
	##var new_speed = max(play_char.velocity.length() - drop, 0.0)
	##if play_char.velocity.length() > 0.0:
		##new_speed /= play_char.velocity.length()
	##play_char.velocity *= new_speed
#
#func move(delta : float):
	##manage the character movement
	#
	##direction input
	#play_char.input_direction = Input.get_vector(play_char.move_left_action, play_char.move_right_action, play_char.move_forward_action, play_char.move_backward_action)
	##get the move direction depending on the input
	#play_char.move_direction = (play_char.cam_holder.global_basis * Vector3(play_char.input_direction.x, 0.0, play_char.input_direction.y)).normalized()
	#
	##set to ensure the character don't exceed the max speed authorized
	##play_char.desired_move_speed = clamp(play_char.desired_move_speed, 0.0, play_char.max_desired_move_speed)
	#
	#if play_char.move_direction and play_char.is_on_floor():
		##transition to corresponding state
		#transitioned.emit(self, play_char.walk_or_run)
	#elif play_char.velocity.x or play_char.velocity.z or play_char.velocity.y > 0:
		#transitioned.emit(self, play_char.walk_or_run)
