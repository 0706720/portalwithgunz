extends CharacterBody3D

@export var grapple_speed: float = 25.0
@export var grapple_pull_strength: float = 40.0
@export var max_grapple_distance: float = 50.0
@export var stop_distance: float = 2.0

var is_grappling: bool = false
var grapple_point: Vector3

@onready var camera = $Camera3D
@onready var ray = $Camera3D/RayCast3D

func _physics_process(delta):
	if Input.is_action_just_pressed("grapple"):
		start_grapple()

	if is_grappling:
		process_grapple(delta)
	else:
		apply_gravity(delta)

	move_and_slide()

func start_grapple():
	ray.target_position = Vector3(0, 0, -max_grapple_distance)
	ray.force_raycast_update()

	if ray.is_colliding():
		grapple_point = ray.get_collision_point()
	is_grappling = true

func process_grapple(delta):
	var direction = (grapple_point - global_transform.origin)
	var distance = direction.length()

	if distance < stop_distance:
		stop_grapple()
	return

	direction = direction.normalized()

	velocity = direction * grapple_pull_strength

func stop_grapple():
	is_grappling = false
	velocity = Vector3.ZERO

func apply_gravity(delta):
	if not is_on_floor():
		velocity.y -= 9.8 * delta
