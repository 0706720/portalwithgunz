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
	
	move(delta)

func applies(delta : float):
	if play_char.hit_ground_cooldown > 0.0: play_char.hit_ground_cooldown -= delta
	
	if !play_char.is_on_floor():
		if play_char.velocity.y < 0.0: 
			transitioned.emit(self, "InairState")

func input_management():
	if Input.is_action_just_pressed(play_char.crouch_action):
		transitioned.emit(self, "CrouchState")

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
		
	else:
		transitioned.emit(self, "IdleState")
	
	if play_char.input_dir != Vector2.ZERO:
		if play_char.movement_anim.current_animation != "Movement_animation":
			play_char.movement_anim.play("Movement_animation")
	else:
		if play_char.movement_anim.current_animation != "Idle":
			play_char.movement_anim.play("Idle")
