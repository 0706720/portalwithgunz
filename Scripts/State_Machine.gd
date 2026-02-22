#state_machine.gd

class_name StateMachine
extends Node

var current_state: State

func change_state(new_state: State) -> void:
	if current_state:
		current_state.exit()
	current_state = new_state
	current_state.enter()

func _physcics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)
