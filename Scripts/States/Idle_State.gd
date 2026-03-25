#idle_state.gd
class_name IdleState
extends State

func physics_process(delta: float) -> void:
	var input = Input.get_vector("left", "right", "up", "down")

	if input.length() > 0:
		#print("walking")
		state_finished.emit("MoveState")
	elif Global.player.is_on_floor() == false:
		state_finished.emit("CrouchState")
		return
