extends Node3D

@onready var spawnPoint1 = $spawnPoint1
@onready var spawnPoint2 = $spawnPoint2
@onready var spawnPoint3 = $spawnPoint3
@onready var spawnPoint4 = $spawnPoint4
@onready var spawnPoint5 = $spawnPoint5
@onready var spawnPoint6 = $spawnPoint6
@onready var spawnPoint7 = $spawnPoint7
@onready var timer = $Timer
var pellet = preload("res://assets/models/ShotgunBullet.tscn")
var spread_angle = 0.5
@export var bullet_speed: float = 20.0
var random_x = randf_range(-spread_angle, spread_angle)
var random_y = randf_range(-spread_angle, spread_angle)
var random_z = randf_range(-spread_angle, spread_angle)

func _ready() -> void:
	pass

func shoot_shotgun():
	if Input.is_action_just_pressed("shoot") and Global.currentWeapon == 'shotgun':
		#timer.start()
		var random_x = randf_range(-spread_angle, spread_angle)
		var random_y = randf_range(-spread_angle, spread_angle)
		var random_z = randf_range(-spread_angle, spread_angle)
		var bullet1 = pellet.instantiate()
		get_tree().root.add_child(bullet1)
		bullet1.global_transform = spawnPoint1.global_transform
		var forward_dir1 = -spawnPoint1.global_transform.basis.z
		var spread_direction1 = (forward_dir1 + Vector3(random_x, random_y, random_z)).normalized()
		if "direction" in bullet1:
			bullet1.direction = spread_direction1
		
		var bullet2 = pellet.instantiate()
		get_tree().root.add_child(bullet2)
		bullet2.global_transform = spawnPoint2.global_transform
		var forward_dir2 = -spawnPoint2.global_transform.basis.z
		var spread_direction2 = (forward_dir2 + Vector3(random_x, random_y, random_z)).normalized()
		if "direction" in bullet2:
			bullet2.direction = spread_direction2
		
		var bullet3 = pellet.instantiate()
		get_tree().root.add_child(bullet3)
		bullet3.global_transform = spawnPoint3.global_transform
		var forward_dir3 = -spawnPoint3.global_transform.basis.z
		var spread_direction3 = (forward_dir3 + Vector3(random_x, random_y, random_z)).normalized()
		if "direction" in bullet3:
			bullet3.direction = spread_direction3
		
		var bullet4 = pellet.instantiate()
		get_tree().root.add_child(bullet4)
		bullet4.global_transform = spawnPoint4.global_transform
		var forward_dir4 = -spawnPoint4.global_transform.basis.z
		var spread_direction4 = (forward_dir4 + Vector3(random_x, random_y, random_z)).normalized()
		if "direction" in bullet4:
			bullet4.direction = spread_direction4
		
		var bullet5 = pellet.instantiate()
		get_tree().root.add_child(bullet5)
		bullet5.global_transform = spawnPoint5.global_transform
		var forward_dir5 = -spawnPoint5.global_transform.basis.z
		var spread_direction5 = (forward_dir5 + Vector3(random_x, random_y, random_z)).normalized()
		if "direction" in bullet5:
			bullet5.direction = spread_direction5
		
		var bullet6 = pellet.instantiate()
		get_tree().root.add_child(bullet6)
		bullet6.global_transform = spawnPoint6.global_transform
		var forward_dir6 = -spawnPoint6.global_transform.basis.z
		var spread_direction6 = (forward_dir6 + Vector3(random_x, random_y, random_z)).normalized()
		if "direction" in bullet6:
			bullet6.direction = spread_direction6
		
		var bullet7 = pellet.instantiate()
		get_tree().root.add_child(bullet7)
		bullet7.global_transform = spawnPoint7.global_transform
		var forward_dir7 = -spawnPoint7.global_transform.basis.z
		var spread_direction7 = (forward_dir7 + Vector3(random_x, random_y, random_z)).normalized()
		if "direction" in bullet7:
			bullet7.direction = spread_direction7
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	shoot_shotgun()
