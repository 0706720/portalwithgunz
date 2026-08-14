extends State

class_name CrouchState

var state_name : String = "Crouch"

var play_char : CharacterBody3D

func enter(play_char_ref : CharacterBody3D):
	#pass the play char refrence 
	play_char = play_char_ref
	
	verifications()
	# moved crouching if statement to it's own function
	crouchCheck()
	

func crouchCheck():
	if play_char._is_crouching and !play_char.crouch_shapecast.is_colliding() and !play_char._using_crouch:
		# if crouch var is true, there are no obstruction above player, and crouch animation isn't running, the uncrouch.
		# same as crouching, but the speed variable is * -1 to go backward. True makes it start from the end.
		play_char.crouch_anim_player.play("Crouch", -1, -play_char.crouch_speed, true)
	elif !play_char._is_crouching and !play_char._using_crouch and play_char.is_on_floor():
		# if crouch var is false, crouch animation isn't running, and player is on floor, crouch.
		play_char.crouch_anim_player.play("Crouch", -1, play_char.crouch_speed)
		
	print("Entered CrouchState")
	
func verifications():
	pass

func physics_update(delta : float):
	if is_multiplayer_authority():
		applies(delta)
		
		play_char.gravity_apply(delta)
		
		input_management()
		
		handle_ground_physics(delta)
		
		move(delta)
	else:
		pass

func applies(delta : float):
	if play_char.velocity.y < 0.0: 
		crouchCheck()
		transitioned.emit(self, "InairState")

	if Input.is_action_just_pressed(play_char.crouch_action):
		if play_char.is_on_floor():
			# extra check so uncrouch is completed before changing state
			crouchCheck()
			if play_char.move_direction: transitioned.emit(self, play_char.walk_or_run)
			else: transitioned.emit(self, "IdleState")

func input_management():
	pass

func handle_ground_physics(delta):
# apply friction
	if play_char.is_on_floor() == true:
		var control = max(play_char.velocity.length(), play_char.ground_deccel)
		var drop = control * play_char.ground_friction * delta
		var new_speed = max(play_char.velocity.length() - drop, 0.0)
		if play_char.velocity.length() > 0:
			new_speed /= play_char.velocity.length()
		play_char.velocity *= new_speed

func move(delta : float):
	play_char.input_direction = Input.get_vector(play_char.move_left_action, play_char.move_right_action, play_char.move_forward_action, play_char.move_backward_action)
	play_char.move_direction = (play_char.cam_holder.global_basis * Vector3(play_char.input_direction.x, 0.0, play_char.input_direction.y)).normalized()
	
	play_char.desired_move_speed = clamp(play_char.desired_move_speed, 0.0, play_char.max_desired_move_speed)
	
	if play_char.move_direction and play_char.is_on_floor():
		#apply smooth move
		play_char.velocity.x = lerp(play_char.velocity.x, play_char.move_direction.x * play_char.crouch_speed, play_char.move_accel * delta)
		play_char.velocity.z = lerp(play_char.velocity.z, play_char.move_direction.z * play_char.crouch_speed, play_char.move_accel * delta)
		
		#if play_char.hit_ground_cooldown <= 0: play_char.desired_move_speed = play_char.velocity.length()


func _on_crouch_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "Crouch":
		# tell system that crouch animation is not being used (prevents overlapping animations)
		play_char._using_crouch = false


func _on_crouch_animation_player_animation_started(anim_name: StringName) -> void:
	if anim_name == "Crouch":
		# tell system player is currently crouching or uncrouching, based on what the boolean was prior.
		play_char._is_crouching = !play_char._is_crouching
		# tell system that crouch animation is being used (prevents overlapping animations)
		play_char._using_crouch = true
