extends Node3D

const GrenadeScene = preload("res://grenade.tscn")
@export var launch_speed: float = 20.0
@onready var SpawnPoint = $SpawnPoint

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("shoot") and Global.currentWeapon == 'Grenade' and Global.weapon_cooldown <= 0:
		shoot_grenade()


func shoot_grenade() -> void:
	adjust_cooldown()
	var grenade = GrenadeScene.instantiate() as RigidBody3D
	adjust_size(grenade)
	get_tree().current_scene.add_child(grenade)
	grenade.global_transform = SpawnPoint.global_transform
	var forward_dir = -SpawnPoint.global_transform.basis.z
	grenade.linear_velocity = forward_dir * launch_speed

func adjust_cooldown():
	var multiplier = Global.grenade_cooldown_bonus 
	if multiplier >= 0:
		# this will ensure that the cooldown doesnt get fully removed
		if multiplier > 9:
			multiplier = 9
		# based on how many cooldown reduction cards have been taken, reduce cooldown by an additional 10% 
		Global.weapon_cooldown = 2.5 - (2.5 / 10.0 * multiplier)
		#print('new cooldown: ' + str(Global.weapon_cooldown))
	else:
		Global.weapon_cooldown = 2.5
		
func adjust_size(grenade_scene):
	if Global.grenade_size_bonus > 0:
		var sf = Global.grenade_size_bonus
		# scaling has to be applied to individual elements because scaling rigidbodies directly yields bad results
		var area = grenade_scene.get_node("Area3D") as Area3D
		# +10% bonus size per stack
		area.scale = Vector3.ONE * ((sf / 10) + 1.0)
		var explosion = grenade_scene.get_node("Grenade_explosion") as Node3D
		explosion.scale = Vector3.ONE * ((sf / 10) + 1.0)
		return grenade_scene
		
