class_name RangedEnemy
extends Enemy

@export var projectile_scene: PackedScene
@onready var line_of_sight: RayCast3D = $LineOfSight

func perform_attack() -> void:
	if not multiplayer.is_server():
		return
		
	if target_player and line_of_sight:
		# Point the raycast directly at the player's position
		line_of_sight.target_position = line_of_sight.to_local(target_player.global_position + Vector3(0, 1.0, 0))
		line_of_sight.force_raycast_update()
		
		# Check if the ray hit something and if that something is the player
		if line_of_sight.is_colliding():
			var collider = line_of_sight.get_collider()
			if collider != target_player:
				# A wall or obstacle is blocking the shot!
				return

	if projectile_scene:
		var bullet = projectile_scene.instantiate()
		get_tree().current_scene.add_child(bullet)
		
		# Spawn cleanly from the front of the enemy instead of dead-center
		bullet.global_position = global_position + (global_transform.basis.z * 1.5) + Vector3(0, 1.0, 0)
		
		if bullet.has_method("initialize"):
			bullet.initialize(target_player.global_position - bullet.global_position, attack_damage)
