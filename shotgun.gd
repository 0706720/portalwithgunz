extends Node3D

@onready var spawnPoint = $spawnPoint
var pellet = preload("res://assets/models/ShotgunBullet.tscn")
var pellet_count = 8
var spread_angle = 0.05
@export var bullet_speed: float = 40.0

func _ready() -> void:
	pass

func shoot_shotgun():
	if Input.is_action_just_pressed("shoot"):
		var bullet = pellet.instantiate()
		get_tree().root.add_child(bullet)
		bullet.global_transform = spawnPoint.global_transform
		var forward_dir = -spawnPoint.global_transform.basis.z
		var random_x = randf_range(-spread_angle, spread_angle)
		var random_y = randf_range(-spread_angle, spread_angle)
		var random_z = randf_range(-spread_angle, spread_angle)
		var spread_direction = (forward_dir + Vector3(random_x, random_y, random_z)).normalized()
		#bullet.direction = spread_direction
		bullet.global_transform = spawnPoint.global_transform



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	shoot_shotgun()
