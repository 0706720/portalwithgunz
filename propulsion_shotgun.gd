extends Node3D

var damage = 15
var spread = 15

@onready var raycasts = $"Raycasts(shotgun)"

func _ready() -> void:
	randomize()
	#for r in raycasts.get_children():
		#r.cast_to.x = randf_range(spread, -spread)
		#r.cast_to.y = randf_range(spread, -spread)

func fire_shotgun():
	if Input.is_action_just_pressed("Fire_shotgun"):
		print_rich("[color=green]Success![/color]")
	#for r in raycasts.get_children():
		#r.cast_to.x = randf_range(spread, -spread)
		#r.cast_to.y = randf_range(spread, -spread)
		#if r.is_colliding():
			#if r.get_collider().is_in_group("player"):
				#r.get_collider().health -= damage
