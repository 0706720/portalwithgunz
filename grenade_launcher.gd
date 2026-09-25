extends Node3D

const GrenadeScene = preload("res://grenade.tscn")
@export var launch_speed: float = 20.0
@onready var SpawnPoint = $SpawnPoint

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("shoot") and Global.currentWeapon == 'grenade':
		shoot_grenade()


func shoot_grenade() -> void:
	var grenade = GrenadeScene.instantiate() as RigidBody3D
	get_tree().current_scene.add_child(grenade)
	grenade.global_transform = SpawnPoint.global_transform
	var forward_dir = -SpawnPoint.global_transform.basis.z
	grenade.linear_velocity = forward_dir * launch_speed
