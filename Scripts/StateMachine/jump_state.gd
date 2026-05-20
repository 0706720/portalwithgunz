extends State

class_name JumpState

var state_name : String = "Jump"

var play_char : CharacterBody3D

func enter(play_char_ref : CharacterBody3D):
	#pass the play char refrence 
	play_char = play_char_ref
	
	verifications()
	
	print("Entered Jump")
func verifications():
	pass

func physics_update(delta : float):
	applies(delta)
	
	#play_char.gravity_apply(delta)
	
	input_management()
	
	move(delta)

func applies(delta : float):
	if play_char.is_on_floor():
		if play_char.move_direction: transitioned.emit(self, play_char.walk_or_run)
		else: transitioned.emit(self, "IdleState")

func input_management():
	pass

func move(delta : float):
	pass
