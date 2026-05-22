extends State

class_name RunState

var state_name : String = "Run"

var play_char : CharacterBody3D

func enter(play_char_ref : CharacterBody3D):
	#pass the play char refrence 
	play_char = play_char_ref

	verifications()

	
	verifications()
	
	print("Entered Run")
func verifications():
	pass

func physics_update(delta : float):
	applies(delta)


	#play_char.gravity_apply(delta)

	input_management()


	
	#play_char.gravity_apply(delta)
	
	input_management()
	
	move(delta)

func applies(delta : float):
	pass


func input_management():
	pass

func move(delta : float):
	pass
