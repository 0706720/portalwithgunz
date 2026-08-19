extends State
class_name WalkState

var state_name := "Walk"
var play_char : CharacterBody3D

# Multiplayer flags
var is_server := false
var is_local_player := false

func enter(play_char_ref : CharacterBody3D):
	play_char = play_char_ref

	is_server = multiplayer.is_server()
	is_local_player = play_char.is_multiplayer_authority()

	verifications()
	print("Entered Walk (server:", is_server, " local:", is_local_player, ")")

func verifications():
	play_char.move_speed = play_char.walk_speed
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

		_handle_ground_physics(delta)
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

		_handle_ground_physics(delta)
		move(delta)

		# sync transform to clients
		rpc("_client_sync_transform", play_char.global_transform)

func applies(delta):
	if play_char.hit_ground_cooldown > 0.0:
		play_char.hit_ground_cooldown -= delta

	if !play_char.is_on_floor():
		if play_char.velocity.y < 0.0:
			transitioned.emit(self, "InairState")

func input_management():
	if Input.is_action_just_pressed(play_char.crouch_action):
		transitioned.emit(self, "CrouchState")

func get_move_speed() -> float:
	var sprint: float = 0.0
	var walk: float = 0.0

	if play_char.sprint_speed != null:
		sprint = play_char.sprint_speed

	if play_char.walk_speed != null:
		walk = play_char.walk_speed

	if Input.is_action_pressed("sprint"):
		return sprint

	return walk

func _handle_ground_physics(delta):
	var cur_speed_in_wish_dir = play_char.velocity.dot(play_char.wish_dir)
	var add_speed_till_cap = get_move_speed() - cur_speed_in_wish_dir

	if add_speed_till_cap > 0:
		var accel_speed = play_char.ground_accel * delta * get_move_speed()
		accel_speed = min(accel_speed, add_speed_till_cap)
		play_char.velocity += accel_speed * play_char.wish_dir

	# friction
	if play_char.is_on_floor():
		var control = max(play_char.velocity.length(), play_char.ground_deccel)
		var drop = control * play_char.ground_friction * delta
		var new_speed = max(play_char.velocity.length() - drop, 0.0)

		if play_char.velocity.length() > 0:
			new_speed /= play_char.velocity.length()

		play_char.velocity *= new_speed

func move(delta):
	play_char.movement_anim.play("Movement_animation")

	play_char.input_direction = Input.get_vector(
		play_char.move_left_action,
		play_char.move_right_action,
		play_char.move_forward_action,
		play_char.move_backward_action
	)

	play_char.move_direction = (
		play_char.cam_holder.global_basis *
		Vector3(play_char.input_direction.x, 0.0, play_char.input_direction.y)
	).normalized()

	play_char.desired_move_speed = clamp(
		play_char.desired_move_speed,
		0.0,
		play_char.max_desired_move_speed
	)

	if play_char.move_direction and play_char.is_on_floor():
		play_char.velocity.x = lerp(
			play_char.velocity.x,
			play_char.move_direction.x * play_char.move_speed,
			play_char.move_accel * delta
		)

		play_char.velocity.z = lerp(
			play_char.velocity.z,
			play_char.move_direction.z * play_char.move_speed,
			play_char.move_accel * delta
		)

		if play_char.hit_ground_cooldown <= 0:
			play_char.desired_move_speed = play_char.velocity.length()

	elif !play_char.velocity.x and play_char.velocity.z >= 0:
		transitioned.emit(self, "IdleState")

	if play_char.input_direction != Vector2.ZERO:
		if play_char.movement_anim.current_animation != "Movement_animation":
			play_char.movement_anim.play("Movement_animation")
	else:
		if play_char.movement_anim.current_animation != "Idle":
			play_char.movement_anim.play("Idle")

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
#class_name WalkState
#
#var state_name : String = "Walk"
#
#var play_char : CharacterBody3D
#
#func enter(play_char_ref : CharacterBody3D):
	##pass the play char refrence 
	#play_char = play_char_ref
	#
	#verifications()
	#
	#print("Entered Walk")
#
#func verifications():
	#play_char.move_speed = play_char.walk_speed
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
		#_handle_ground_physics(delta)
		#
		#move(delta)
	#else:
		#pass
	#
#
#
#func applies(delta : float):
	#if play_char.hit_ground_cooldown > 0.0: play_char.hit_ground_cooldown -= delta
	#
	#if !play_char.is_on_floor():
		#if play_char.velocity.y < 0.0: 
			#transitioned.emit(self, "InairState")
#
#func input_management():
	#if Input.is_action_just_pressed(play_char.crouch_action):
		#transitioned.emit(self, "CrouchState")
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
	#if play_char.is_on_floor() == true:
		#var control = max(play_char.velocity.length(), play_char.ground_deccel)
		#var drop = control * play_char.ground_friction * delta
		#var new_speed = max(play_char.velocity.length() - drop, 0.0)
		#if play_char.velocity.length() > 0:
			#new_speed /= play_char.velocity.length()
		#play_char.velocity *= new_speed
#
#func move(delta : float):
	#play_char.movement_anim.play("Movement_animation")
	#play_char.input_direction = Input.get_vector(play_char.move_left_action, play_char.move_right_action, play_char.move_forward_action, play_char.move_backward_action)
	#play_char.move_direction = (play_char.cam_holder.global_basis * Vector3(play_char.input_direction.x, 0.0, play_char.input_direction.y)).normalized()
	#
	#play_char.desired_move_speed = clamp(play_char.desired_move_speed, 0.0, play_char.max_desired_move_speed)
	#
	#if play_char.move_direction and play_char.is_on_floor():
		##apply smooth move
		#play_char.velocity.x = lerp(play_char.velocity.x, play_char.move_direction.x * play_char.move_speed, play_char.move_accel * delta)
		#play_char.velocity.z = lerp(play_char.velocity.z, play_char.move_direction.z * play_char.move_speed, play_char.move_accel * delta)
		#
		#if play_char.hit_ground_cooldown <= 0: play_char.desired_move_speed = play_char.velocity.length()
		#
	#elif !play_char.velocity.x and play_char.velocity.z >= 0:
		#transitioned.emit(self, "IdleState")
	#
	#if play_char.input_dir != Vector2.ZERO:
		#if play_char.movement_anim.current_animation != "Movement_animation":
			#play_char.movement_anim.play("Movement_animation")
	#else:
		#if play_char.movement_anim.current_animation != "Idle":
			#play_char.movement_anim.play("Idle")
