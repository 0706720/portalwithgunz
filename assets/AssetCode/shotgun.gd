extends Node3D

@export var pellet_count: int = 7
@export var spread_angle: float = 0.15
@export var fire_cooldown: float = 1.0

@onready var anim_player = $AnimationPlayer
@onready var muzzle_flash = $MuzzleFlash
@onready var spawn_point = get_node_or_null("SpawnPoint") # Falls back to self if null

var pellet_scene = preload("res://assets/models/ShotgunBullet.tscn")
var weapon_manager: Node = null
var is_cooling_down: bool = false

func _ready() -> void:
	randomize()
	# Walk up hierarchy to locate weaponsManager
	var p = get_parent()
	while p:
		if p.has_node("weaponsManager"):
			weapon_manager = p.get_node("weaponsManager")
			break
		p = p.get_parent()

func _process(delta: float) -> void:
	# Only authority processes local firing inputs
	if not is_multiplayer_authority():
		return
		
	shoot_shotgun()

func shoot_shotgun() -> void:
	var active_weapon = weapon_manager.get("current_weapon_name") if weapon_manager else ""
	
	if (Input.is_action_just_pressed("shoot") or Input.is_action_just_pressed("Fire_shotgun")) \
		and active_weapon == 'Shotgun' \
		and not is_cooling_down:
		
		is_cooling_down = true
		play_shoot_effects()
		
		# Determine spawn origin transform
		var origin_tf = spawn_point.global_transform if spawn_point else global_transform
		
		# Sync pellet instantiation across all network peers
		rpc("server_spawn_pellets", origin_tf)
		
		await get_tree().create_timer(fire_cooldown).timeout
		is_cooling_down = false

@rpc("any_peer", "call_local", "reliable")
func server_spawn_pellets(origin_transform: Transform3D) -> void:
	for i in range(pellet_count):
		var bullet = pellet_scene.instantiate() as Area3D
		if not bullet:
			continue
			
		get_tree().current_scene.add_child(bullet)
		bullet.global_transform = origin_transform
		
		# Pass the player who fired this bullet so the bullet knows who to ignore!
		if "shooter" in bullet:
			bullet.shooter = self.owner # Or your player root node
		
		var rand_x = randf_range(-spread_angle, spread_angle)
		var rand_y = randf_range(-spread_angle, spread_angle)
		bullet.rotate_object_local(Vector3.RIGHT, rand_x)
		bullet.rotate_object_local(Vector3.UP, rand_y)

func play_shoot_effects() -> void:
	if anim_player and anim_player.has_animation("Shoot Shotgun"):
		anim_player.stop()
		anim_player.play("Shoot Shotgun")
	if muzzle_flash:
		muzzle_flash.restart()
		muzzle_flash.emitting = true
