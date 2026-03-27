extends Node3D

var damage = 15
var spread = 15
@export var anim_playing = false

@onready var bullet
@onready var raycasts = $"Raycasts(shotgun)"
@onready var anim_player = $AnimationPlayer
@onready var muzzle_flash = $MuzzleFlash


func _physics_process(delta):
	fire_shotgun()

func _ready() -> void:
	randomize()

func fire_shotgun():
	if anim_playing == false:
		if Input.is_action_just_pressed("Fire_shotgun"):
			anim_playing = true
			play_shoot_effects()
			print("SHOTGUN FIRED")
		#var shoot_dir = -camera.global_transform.basis.z.normalized()
		#velocity += -shoot_dir * recoil_force



			for r in raycasts.get_children():
			# Apply spread
				r.target_position.x = randf_range(-spread, spread)
				r.target_position.y = randf_range(-spread, spread)

			# Force update
				r.force_raycast_update()

			# Check hit
				if r.is_colliding():
					var collider = r.get_collider()
			await get_tree().create_timer(5.0).timeout
			anim_playing = false



func play_shoot_effects():
	anim_player.stop()
	anim_player.play("Shoot Shotgun")
	muzzle_flash.restart()
	muzzle_flash.emitting = true
