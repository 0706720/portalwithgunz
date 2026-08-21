extends Node
class_name StateMachine

@export var initial_state: Node
var current_state: State
var owner_character: CharacterBody3D

func _ready():
	owner_character = get_parent()
	current_state = initial_state as State

	for child in get_children():
		if child.has_signal("transitioned"):
			child.connect("transitioned", Callable(self, "_on_state_transition"))

func physics_update(delta):
	if current_state and current_state.has_method("physics_update"):
		current_state.physics_update(delta, owner_character)

func _on_state_transition(from_state: State, to_state_name: String):
	var next_state: State = get_node_or_null(to_state_name) as State
	if next_state:
		current_state = next_state
		current_state.enter(owner_character)
	else:
		push_warning("StateMachine: Could not find state '%s'" % to_state_name)

##state_machine
#
#extends Node
#
#class_name StateMachine
#
#@export var initial_state : State
#
#var curr_state : State
#var curr_state_name  : String
#var states : Dictionary = {}
#
#@onready var play_char : CharacterBody3D = $".."
#
#signal change_fov
#signal change_cam_position
#
#func _ready() -> void:
	##get all the state childrens
	#for child in get_children():
		#if child is State:
			#states[child.name.to_lower()] = child
			#child.transitioned.connect(on_state_child_transition)
			#
	##if initial state, transition to it
	#if initial_state:
		#initial_state.enter(play_char)
		#curr_state = initial_state
		#curr_state_name = curr_state.state_name
		#
#func _process(delta : float) -> void:
	#if curr_state: curr_state.update(delta)
	#
#func _physics_process(delta: float) -> void:
	#if curr_state: curr_state.physics_update(delta)
	#
#func on_state_child_transition(state : State, new_state_name : String) -> void:
	##manage the transition from one state to another
	#
	#if state != curr_state: return
	#
	#var new_state = states.get(new_state_name.to_lower())
	#if !new_state: return
	#
	##exit the current state
	#if curr_state: curr_state.exit()
	#
	##enter the new state
	#new_state.enter(play_char)
	#
	#curr_state = new_state
	#curr_state_name = curr_state.state_name
