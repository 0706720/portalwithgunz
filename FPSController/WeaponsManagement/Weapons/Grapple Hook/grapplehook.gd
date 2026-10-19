extends Node3D

@export var pull_force: float = 50.0
@export var rope_length_slack: float = 1.0
@export var grapple_duration: float = 15.0

var grapple_point: Vector3
var last_shot_point: Vector3
var rope_length: float
var grappling: bool = false

@onready var grapple_cast: RayCast3D = $RayCast3D
@onready var grapple_timer: Timer = $Timer
@onready var hook_origin: Node3D = $HookOrigin
@onready var rope: MeshInstance3D = $Rope
@onready var look_point = $lookpoint
@onready var player: CharacterBody3D = $"../../.."

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("shoot") and !grappling and Global.currentWeapon == "GrappleGun" and Global.weapon_cooldown <= 0:
		start_grapple()
	if Input.is_action_just_released("shoot"):
		stop_grapple()
	if grappling:
		update_grapple(delta)
		update_rope()


func start_grapple() -> void:
	grapple_cast.force_raycast_update()
	if !grapple_cast.is_colliding():
		return
	grapple_point = grapple_cast.get_collision_point()
	last_shot_point = grapple_point
	rope_length = player.global_position.distance_to(grapple_point)
	grappling = true
	rope.visible = true
	grapple_timer.start(grapple_duration)

func stop_grapple() -> void:
	grappling = false
	rope.visible = false
	grapple_timer.stop()

func update_grapple(delta: float) -> void:
	var to_hook = grapple_point - player.global_position
	var direction = to_hook.normalized()
	player.velocity += direction * pull_force * delta
	print(player.velocity)

func update_rope() -> void:
	var start = hook_origin.global_position
	var end = grapple_point
	var distance = start.distance_to(end)
	
	# 1. Place the rope at the exact midpoint between the gun and the wall
	rope.global_position = (start + end) * 0.5
	
	# 2. Point the rope toward the grapple point
	rope.look_at(end, Vector3.UP)
	rope.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	
	# 3. Scale by the FULL distance unit-for-unit (since it scales out from the center)
	rope.scale = Vector3(1.0, distance * 2.0, 1.0)

func _on_timer_timeout() -> void:
	stop_grapple()
