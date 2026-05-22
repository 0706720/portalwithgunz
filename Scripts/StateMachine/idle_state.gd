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
	applies(delta)
	
	#play_char.gravity_apply(delta)
	
	input_management()
	
	move(delta)

func applies(delta : float):
	if play_char.velocity.y < 0.0: transitioned.emit(self, "InairState")

func input_management():
	if Input.is_action_just_pressed(play_char.crouch_action):
		transitioned.emit(self, "CrouchState")
		
	if Input.is_action_just_pressed(play_char.run_action):
		if play_char.walk_or_run == "WalkState": play_char.walk_or_run = "RunState"
		elif play_char.walk_or_run == "RunState": play_char.walk_or_run = "WalkState"
	
	if play_char.is_on_floor():
		if Input.is_action_just_pressed("spin_dash"):
			transitioned.emit(self, "SpindashState")
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
