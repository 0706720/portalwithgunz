#move_state.gd
class_name MoveState
extends State

func physics_update(delta: float) -> void:
	var input = Input.get_vector("left", "right", "up", "down")

	if input.length() == 0:
		#print("hi")
		state_finished.emit("IdleState")
	elif Global.player.is_on_floor() == false:
		state_finished.emit("CrouchState")
		return
