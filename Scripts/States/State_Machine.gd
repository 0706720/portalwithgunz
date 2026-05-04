#state_machine

extends Node

@export var initial_state: NodePath
@onready var current_state: State = get_node(initial_state)

func _ready():
	for child in get_children():
		child.state_machine = self
	current_state.enter()

func _process(delta):
	current_state.update(delta)

func _physics_process(delta):
	current_state.physics_update(delta)

func transition_to(target_state_name: String):
	if not has_node(target_state_name):
		return
		
	current_state.exit()
	current_state = get_node(target_state_name)
	current_state.enter()
