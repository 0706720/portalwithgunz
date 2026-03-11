#state_machine.gd

class_name StateMachine
extends Node

@export var current_state: State
var states: Dictionary = {}

func ready():
	for child in State:
		if child is State:
			states[child.name] = child.transition.connect(change_state)

func change_state(new_state_name: StringName) -> void:
	var new_state = states.get(new_state_name)
	if new_state != null:
		if new_state != current_state:
			current_state.exit()
			current_state = new_state
			current_state.enter()
	else:
		push_warning("State does not exist")
		
func _physics_process(delta):
	current_state.physics_update(delta)
