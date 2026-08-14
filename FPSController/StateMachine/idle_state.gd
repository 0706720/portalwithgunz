extends State

class_name IdleState

var state_name : String = "Idle"

var play_char : CharacterBody3D

func enter(play_char_ref : CharacterBody3D):
	#pass the play char refrence 
	play_char = play_char_ref
	
	verifications()
	
	print("Entered Idle")

func verifications():
	pass

func physics_update(delta : float):
	if is_multiplayer_authority():
		applies(delta)
		
		play_char.gravity_apply(delta)
		
		input_management()
		
		_handle_ground_physics(delta)
		
		move(delta)
	else:
		pass

func applies(delta : float):
	if play_char.velocity.y < 0.0: 
		transitioned.emit(self, "InairState")

func input_management():
	if Input.is_action_just_pressed(play_char.crouch_action):
		transitioned.emit(self, "CrouchState")
		
	if Input.is_action_just_pressed(play_char.run_action):
		if play_char.walk_or_run == "WalkState": play_char.walk_or_run = "RunState"
		elif play_char.walk_or_run == "RunState": play_char.walk_or_run = "WalkState"
	
	if play_char.is_on_floor():
		if Input.is_action_just_pressed("spin_dash"):
			transitioned.emit(self, "SpindashState")

func get_move_speed():
	if Input.is_action_just_pressed("sprint"):
		return play_char.sprint_speed 
	else:
		return play_char.walk_speed

func _handle_ground_physics(delta):
# simmilar to the air movement. Acceleration and friction on ground.
	var cur_speed_in_wish_dir = play_char.velocity.dot(play_char.wish_dir)
	var add_speed_till_cap = get_move_speed() - cur_speed_in_wish_dir
	if add_speed_till_cap > 0:
		var accel_speed = play_char.ground_accel * delta * get_move_speed()
		accel_speed = min(accel_speed, add_speed_till_cap)
		play_char.velocity += accel_speed * play_char.wish_dir

	# apply friction
	#var control = max(play_char.velocity.length(), play_char.ground_deccel)
	#var drop = control * play_char.ground_friction * delta
	#var new_speed = max(play_char.velocity.length() - drop, 0.0)
	#if play_char.velocity.length() > 0.0:
		#new_speed /= play_char.velocity.length()
	#play_char.velocity *= new_speed

func move(delta : float):
	#manage the character movement
	
	#direction input
	play_char.input_direction = Input.get_vector(play_char.move_left_action, play_char.move_right_action, play_char.move_forward_action, play_char.move_backward_action)
	#get the move direction depending on the input
	play_char.move_direction = (play_char.cam_holder.global_basis * Vector3(play_char.input_direction.x, 0.0, play_char.input_direction.y)).normalized()
	
	#set to ensure the character don't exceed the max speed authorized
	#play_char.desired_move_speed = clamp(play_char.desired_move_speed, 0.0, play_char.max_desired_move_speed)
	
	if play_char.move_direction and play_char.is_on_floor():
		#transition to corresponding state
		transitioned.emit(self, play_char.walk_or_run)
	elif play_char.velocity.x or play_char.velocity.z or play_char.velocity.y > 0:
		transitioned.emit(self, play_char.walk_or_run)
