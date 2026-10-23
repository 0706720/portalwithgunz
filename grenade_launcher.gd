extends Node3D

const GrenadeScene = preload("res://grenade.tscn")
@export var launch_speed: float = 50.0
@onready var SpawnPoint = $SpawnPoint

var weapon_manager: Node = null

func _ready() -> void:
	# Dynamically locate the weaponsManager on the parent character
	weapon_manager = get_node_or_null("../../weaponsManager")
	if not weapon_manager:
		weapon_manager = get_node_or_null("../../../weaponsManager")

func _process(delta: float) -> void:
	if not is_multiplayer_authority():
		return
		
	var active_weapon = weapon_manager.get("current_weapon_name") if weapon_manager else ""
	if Input.is_action_just_pressed("shoot") and active_weapon == 'Grenade' and Global.weapon_cooldown <= 0:
		shoot_grenade()

func shoot_grenade() -> void:
	adjust_cooldown()
	rpc("server_spawn_grenade", SpawnPoint.global_transform, launch_speed)

@rpc("any_peer", "call_local", "reliable")
func server_spawn_grenade(spawn_tf: Transform3D, speed: float) -> void:
	var grenade = GrenadeScene.instantiate() as RigidBody3D
	adjust_size(grenade)
	get_tree().current_scene.add_child(grenade)
	grenade.global_transform = spawn_tf
	var forward_dir = -spawn_tf.basis.z
	grenade.linear_velocity = forward_dir * speed

func adjust_cooldown():
	var multiplier = Global.grenade_cooldown_bonus 
	if multiplier >= 0:
		if multiplier > 9:
			multiplier = 9
		Global.weapon_cooldown = 2.5 - (2.5 / 10.0 * multiplier)
	else:
		Global.weapon_cooldown = 2.5
		
func adjust_size(grenade_scene):
	if Global.grenade_size_bonus > 0:
		var sf = Global.grenade_size_bonus
		var area = grenade_scene.get_node("Area3D") as Area3D
		if area:
			area.scale = Vector3.ONE * ((sf / 10) + 1.0)
		var explosion = grenade_scene.get_node("Grenade_explosion") as Node3D
		if explosion:
			explosion.scale = Vector3.ONE * ((sf / 10) + 1.0)
	return grenade_scene
