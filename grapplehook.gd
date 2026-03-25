extends CharacterBody3D

@export var speed = 10.0
@export var grapple_speed = 25.0
@export var gravity = 20.0

@onready var camera = $Camera3D
@onready var raycast = $Camera3D/RayCast3D

var velocity = Vector3.ZERO

var is_grappling = false
var grapple_point = Vector3.ZERO

func _physics_process(delta):
	if not is_grappling:
		normal_movement(delta)
	else:
		grapple_movement(delta)

func normal_movement(delta):
	var dir = Vector3.ZERO

	if Input.is_action_pressed("move_forward"):
		dir -= camera.global_transform.basis.z
	if Input.is_action_pressed("move_back"):
	dir += camera.global_transform.basis.z
	if Input.is_action_pressed("move_left"):
	dir -= camera.global_transform.basis.x
	if Input.is_action_pressed("move_right"):
	dir += camera.global_transform.basis.x

	dir = dir.normalized()

	velocity.x = dir.x * speed
	velocity.z = dir.z * speed

	if not is_on_floor():
	velocity.y -= gravity * delta
	else:
	velocity.y = 0

	move_and_slide()

func grapple_movement(delta):
	var direction = (grapple_point - global_transform.origin).normalized()

	velocity = direction * grapple_speed

move_and_slide()

# Stop when close
	if global_transform.origin.distance_to(grapple_point) < 2.0:
	is_grappling = false

func _input(event):
	if Input.is_action_just_pressed("fire_grapple"):
	shoot_grapple()

	if Input.is_action_just_released("fire_grapple"):
	is_grappling = false

func shoot_grapple():
	raycast.force_raycast_update()

	if raycast.is_colliding():
	grapple_point = raycast.get_collision_point()
	is_grappling = true
