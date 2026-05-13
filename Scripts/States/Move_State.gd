#move_state.gd

extends State

@export var speed = 5.0

func physics_update(_delta):
	var input_dir = Input.get_vector("left", "right", "forward", "back")
	
	# Transition to Idle if no input
	if input_dir.length() == 0:
		state_machine.transition_to("Idle")
		return

	# Handle 3D Movement
	var direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	player.move_and_slide()
