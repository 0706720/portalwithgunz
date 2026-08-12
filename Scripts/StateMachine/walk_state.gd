extends State

class_name WalkState

var state_name : String = "Walk"

var play_char : CharacterBody3D

func enter(play_char_ref : CharacterBody3D):
	#pass the play char refrence 
	play_char = play_char_ref
	
	verifications()
	
	print("Entered Walk")

func verifications():
	play_char.move_speed = play_char.walk_speed
	play_char.move_accel = play_char.walk_accel
	play_char.move_deccel = play_char.walk_deccel

func physics_update(delta : float):
	applies(delta)
	
	play_char.gravity_apply(delta)
	
	input_management()
	
	_handle_ground_physics(delta)
	
	move(delta)
	


func applies(delta : float):
	if play_char.hit_ground_cooldown > 0.0: play_char.hit_ground_cooldown -= delta
	
	if !play_char.is_on_floor():
		if play_char.velocity.y < 0.0: 
			transitioned.emit(self, "InairState")

func input_management():
	if Input.is_action_just_pressed(play_char.crouch_action):
		transitioned.emit(self, "CrouchState")

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
	if play_char.is_on_floor() == true:
		var control = max(play_char.velocity.length(), play_char.ground_deccel)
		var drop = control * play_char.ground_friction * delta
		var new_speed = max(play_char.velocity.length() - drop, 0.0)
		if play_char.velocity.length() > 0:
			new_speed /= play_char.velocity.length()
		play_char.velocity *= new_speed

func move(delta : float):
	play_char.movement_anim.play("Movement_animation")
	play_char.input_direction = Input.get_vector(play_char.move_left_action, play_char.move_right_action, play_char.move_forward_action, play_char.move_backward_action)
	play_char.move_direction = (play_char.cam_holder.global_basis * Vector3(play_char.input_direction.x, 0.0, play_char.input_direction.y)).normalized()
	
	play_char.desired_move_speed = clamp(play_char.desired_move_speed, 0.0, play_char.max_desired_move_speed)
	
	if play_char.move_direction and play_char.is_on_floor():
		#apply smooth move
		play_char.velocity.x = lerp(play_char.velocity.x, play_char.move_direction.x * play_char.move_speed, play_char.move_accel * delta)
		play_char.velocity.z = lerp(play_char.velocity.z, play_char.move_direction.z * play_char.move_speed, play_char.move_accel * delta)
		
		if play_char.hit_ground_cooldown <= 0: play_char.desired_move_speed = play_char.velocity.length()
		
	elif !play_char.velocity.x and play_char.velocity.z >= 0:
		transitioned.emit(self, "IdleState")
	
	if play_char.input_dir != Vector2.ZERO:
		if play_char.movement_anim.current_animation != "Movement_animation":
			play_char.movement_anim.play("Movement_animation")
	else:
		if play_char.movement_anim.current_animation != "Idle":
			play_char.movement_anim.play("Idle")
