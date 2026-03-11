extends Node

@export var ray: RayCast3D

@onready var player:CharacterBody3D = get_parent()

@export var rest_length = 2.0
@export var stiffness = 10.0
@export var damping = 1.0

var target: Vector3
var launched = false 

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("Grapple"):
		launch()
	if Input. is_action_just_released("Grapple"):
		retract()
		
	if launched:
		handle_grapple(delta)
	
func launch():
	if ray.is_colliding():
		target= ray.get_collision_point()
		launched= true 

func retract():
	launched= false 
	
func handle_grapple(delta: float):
	var target_dir = player.global_position.direction_to(target)
