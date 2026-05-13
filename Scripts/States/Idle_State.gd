#idle_state.gd

extends State

func enter():
	# Play idle animation here
	# player.get_node("AnimationPlayer").play("idle")
	pass

func physics_update(_delta):
	# Check for movement input to transition
	var input_dir = Input.get_vector("left", "right", "forward", "back")
	if input_dir.length() > 0:
		state_machine.transition_to("Walking")
