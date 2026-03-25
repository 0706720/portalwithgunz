extends Node3D

var damage = 15
var spread = 15

@onready var bullet
@onready var raycasts = $"Raycasts(shotgun)"
@onready var anim_player = $AnimationPlayer


func _physics_process(delta):
	fire_shotgun()

func _ready() -> void:
	randomize()

func fire_shotgun():
	if Input.is_action_just_pressed("Fire_shotgun"):
		play_shoot_effects()
		print("SHOTGUN FIRED")


		for r in raycasts.get_children():
			# Apply spread
			r.target_position.x = randf_range(-spread, spread)
			r.target_position.y = randf_range(-spread, spread)

			# Force update
			r.force_raycast_update()

			# Check hit
			if r.is_colliding():
				var collider = r.get_collider()
				print("Hit: ", collider.name)


func play_shoot_effects():
	anim_player.stop()
	anim_player.play("Shoot Shotgun")
