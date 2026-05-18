extends State

class_name IdleState

var state_name : String = "Idle"

var play_char : CharacterBody3D

func enter(play_char_ref : CharacterBody3D):
	#pass the play char refrence 
	play_char = play_char_ref
	
	verifications()

func verifications():
	pass

func physics_update(delta : float):
	applies(delta)
	
	#play_char.gravity_apply(delta)
	
	input_management()
	
	move(delta)

func applies(delta : float):
	pass

func input_management():
	if Input.is_action_just_pressed(play_char.run_action):
		if play_char.walk_or_run == "WalkState": play_char.walk_or_run = "RunState"
		elif play_char.walk_or_run == "RunState": play_char.walk_or_run = "WalkState"

func move(delta : float):
	pass
