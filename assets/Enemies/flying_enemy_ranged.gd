class_name FlyingRangedEnemy
extends Enemy

@export_category("Flight Configuration")
@export var min_flight_altitude := 1.5    
@export var max_flight_altitude := 7.0    
@export var float_bob_speed := 3.0         
@export var float_bob_intensity := 0.4     

@export_category("Ranged Attack Configuration")
@export var projectile_scene: PackedScene
@onready var line_of_sight: RayCast3D = $LineOfSight

var time_passed := 0.0

func _physics_process(delta: float) -> void:
	# ==========================================
	# CLIENT SIDE: Smoothly interpolate transforms received from server
	# ==========================================
	if not multiplayer.is_server():
		global_transform = global_transform.interpolate_with(targeted_client_transform, delta * 15.0)
		return

	# ==========================================
	# SERVER SIDE: Flight AI & Movement Logic
	# ==========================================
	target_refresh_timer -= delta
	if target_refresh_timer <= 0.0 or not target_player or not is_instance_valid(target_player):
		target_refresh_timer = 1.0
		find_player()

	if not target_player:
		return

	if wall_hit_cooldown > 0.0:
		wall_hit_cooldown -= delta
	if attack_timer > 0.0:
		attack_timer -= delta

	time_passed += delta
	var distance_to_player = global_position.distance_to(target_player.global_position)

	# 1. Aggro Check
	if not is_aggroed:
		if distance_to_player <= aggro_range:
			is_aggroed = true
		else:
			velocity = velocity.move_toward(Vector3.ZERO, speed * delta * 3.0)
			move_and_slide()
			_try_sync_transform(delta)
			return
	else:
		if distance_to_player > aggro_range * 2.0:
			is_aggroed = false
			_try_sync_transform(delta)
			return

	# 2. Attack Trigger Check
	if distance_to_player <= attack_range:
		if attack_timer <= 0.0:
			perform_attack() 
			attack_timer = attack_cooldown

	# 3. Smoothly face the player in 3D space
	if distance_to_player > 0.5:
		var look_target = target_player.global_position
		if target_player.has_node("AimTarget"):
			look_target = target_player.get_node("AimTarget").global_position
		else:
			look_target += Vector3(0, 0.5, 0)
			
		var target_transform = global_transform.looking_at(look_target, Vector3.UP)
		global_transform = global_transform.interpolate_with(target_transform, delta * 10.0)

	# 4. Flight Wander Timer
	movement_timer -= delta
	if movement_timer <= 0.0:
		movement_timer = randf_range(1.5, 4.0)
		pick_new_wander_direction()

	# 5. 3D Flight Movement Calculations
	var to_player = (target_player.global_position - global_position)
	var dir_to_player = to_player.normalized()

	var separation_force := Vector3.ZERO
	for sibling in get_parent().get_children():
		if sibling != self and sibling is CharacterBody3D:
			var dist = global_position.distance_to(sibling.global_position)
			if dist < 2.5 and dist > 0.0: 
				var push_dir = (global_position - sibling.global_position)
				separation_force += push_dir.normalized() / dist

	var target_velocity := Vector3.ZERO
	if distance_to_player > max_preferred_distance:
		var final_dir = (dir_to_player + (current_wander_dir * 0.4) + (separation_force * separation_weight)).normalized()
		target_velocity = final_dir * speed
	elif distance_to_player < min_preferred_distance:
		var final_dir = (-dir_to_player + (current_wander_dir * 0.4) + (separation_force * separation_weight)).normalized()
		target_velocity = final_dir * speed
	else:
		var final_dir = (current_wander_dir + (separation_force * separation_weight)).normalized()
		target_velocity = final_dir * (speed * 0.7)

	target_velocity.y += sin(time_passed * float_bob_speed) * float_bob_intensity

	if global_position.y <= min_flight_altitude and target_velocity.y < 0:
		target_velocity.y = 0
	elif global_position.y >= max_flight_altitude and target_velocity.y > 0:
		target_velocity.y = 0

	velocity.x = move_toward(velocity.x, target_velocity.x, speed * delta * 5.0)
	velocity.y = move_toward(velocity.y, target_velocity.y, speed * delta * 5.0)
	velocity.z = move_toward(velocity.z, target_velocity.z, speed * delta * 5.0)

	move_and_slide()
	
	# Use the base class throttled sync helper so it doesn't flood the network
	_try_sync_transform(delta)

func perform_attack() -> void:
	if not multiplayer.is_server():
		return
		
	var target_pos = target_player.global_position
	if target_player.has_node("AimTarget"):
		target_pos = target_player.get_node("AimTarget").global_position
	else:
		target_pos += Vector3(0, 0.5, 0)
		
	if has_node("LineOfSight"):
		var los: RayCast3D = $LineOfSight
		los.target_position = los.to_local(target_pos)
		los.force_raycast_update()
		if los.is_colliding() and los.get_collider() != target_player:
			return

	if projectile_scene:
		var spawn_pos = global_position + (-global_transform.basis.z * 1.5) + Vector3(0, 0.5, 0)
		var shoot_dir = (target_pos - spawn_pos).normalized()
		
		rpc("rpc_spawn_bullet", spawn_pos, shoot_dir)

@rpc("authority", "call_local", "reliable")
func rpc_spawn_bullet(spawn_pos: Vector3, shoot_dir: Vector3) -> void:
	if projectile_scene:
		var bullet = projectile_scene.instantiate()
		get_tree().current_scene.add_child(bullet)
		bullet.global_position = spawn_pos
		
		if bullet.has_method("initialize"):
			bullet.initialize(shoot_dir, attack_damage)
