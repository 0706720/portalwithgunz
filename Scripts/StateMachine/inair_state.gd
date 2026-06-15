extends State

class_name InairState

var state_name : String = "Inair"

var play_char : CharacterBody3D

func enter(play_char_ref : CharacterBody3D):
	#pass the play char refrence 
	play_char = play_char_ref
	
	verifications()
	
	print("Entered Inair")
func verifications():
	play_char.move_speed = play_char.air_speed
	play_char.move_accel = play_char.walk_accel
	play_char.move_deccel = play_char.walk_deccel

func physics_update(delta : float):
	applies(delta)
	
	play_char.gravity_apply(delta)
	
	input_management()
	
	move(delta)

func applies(delta : float):
	if play_char.is_on_floor():
		if play_char.move_direction: transitioned.emit(self, play_char.walk_or_run)
		else: transitioned.emit(self, "IdleState")

func input_management():
	pass

func move(delta : float):
	#play_char.velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta
	
	var cur_speed_in_wish_dir = play_char.velocity.dot(play_char.wish_dir)
	var capped_speed = min((play_char.air_speed * play_char.wish_dir).length(), play_char.air_cap)
	var add_speed_till_cap = capped_speed - cur_speed_in_wish_dir
	if add_speed_till_cap > 0:
		var accel_speed = play_char.air_accel * play_char.air_speed * delta
		accel_speed = min(accel_speed, add_speed_till_cap)
		play_char.velocity += accel_speed * play_char.wish_dir
