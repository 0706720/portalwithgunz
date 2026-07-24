extends Node3D

@onready var raycast = %portalRaycast

func _physics_process(delta):
	fire_portal_gun()

func _ready() -> void:
	pass

func fire_portal_gun():
	if Input.is_action_just_pressed("shoot") and Global.currentWeapon == 'PortalGun':
		print("PORTAL GUN FIRED")
		print("Raycast enabled: ", raycast.enabled)
		print("Raycast colliding: ", raycast.is_colliding())

		if raycast.is_colliding():
			var collider = raycast.get_collider()
			print('HIT DETECTED')
			var hit_point = raycast.get_collision_point()
			print(hit_point)
		else:
			print("No collision detected")
