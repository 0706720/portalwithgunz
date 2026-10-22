class_name RangedEnemy
extends Enemy

@export var projectile_scene: PackedScene
@onready var line_of_sight: RayCast3D = $LineOfSight

func perform_attack() -> void:
	if not multiplayer.is_server():
		return
		
	# Target the AimTarget node if it exists, otherwise fall back to a balanced chest height (0.5)
	var target_pos = target_player.global_position
	if target_player.has_node("AimTarget"):
		target_pos = target_player.get_node("AimTarget").global_position
	else:
		target_pos += Vector3(0, 0.5, 0)
		
	if line_of_sight:
		line_of_sight.target_position = line_of_sight.to_local(target_pos)
		line_of_sight.force_raycast_update()
		
		# Check if a wall or obstacle is blocking the shot
		if line_of_sight.is_colliding():
			var collider = line_of_sight.get_collider()
			if collider != target_player:
				return

	if projectile_scene:
		# Spawn cleanly from the front of the enemy (-Z forward)
		var spawn_pos = global_position + (-global_transform.basis.z * 1.5) + Vector3(0, 0.8, 0)
		var shoot_dir = (target_pos - spawn_pos).normalized()
		
		# RPC call ensures bullets spawn and move on server and all clients simultaneously
		rpc("rpc_spawn_bullet", spawn_pos, shoot_dir)

@rpc("authority", "call_local", "reliable")
func rpc_spawn_bullet(spawn_pos: Vector3, shoot_dir: Vector3) -> void:
	if projectile_scene:
		var bullet = projectile_scene.instantiate()
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = spawn_pos
		
		if bullet.has_method("initialize"):
			bullet.initialize(shoot_dir, attack_damage)
