extends CharacterBody3D

@export var speed := 3.0
@export var aggro_range := 30.0         

# 3D Range Band for distance tracking
@export var min_preferred_distance := 8.0   
@export var max_preferred_distance := 18.0   

# Altitude Boundaries (Global Y-axis limits)
@export var min_flight_altitude := 1.5   
@export var max_flight_altitude := 7.0   

@export var separation_weight := 1.5        
@export var float_bob_speed := 3.0       
@export var float_bob_intensity := 0.4   

var target_player: Node3D = null
var is_aggroed := false

var movement_timer := 0.0
var current_wander_dir := Vector3.ZERO
var time_passed := 0.0
var target_refresh_timer := 0.0

func _ready() -> void:
	# Physics process is left active so the MultiplayerSynchronizer can update clients
	await get_tree().physics_frame
	find_player()
	movement_timer = randf_range(1.0, 3.0)
	pick_new_wander_direction()

func find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	#print("[Enemy Debug] Total players found in 'player' group: ", players.size())
	
	if players.is_empty():
		target_player = null
		#print("[Enemy Debug] Warning: No players found in the group!")
		return
		
	var closest_player = players[0]
	var min_distance = global_position.distance_to(closest_player.global_position)
	#print("[Enemy Debug] Checking player 0 at position: ", closest_player.global_position, " | Distance: ", min_distance)
	
	for i in range(1, players.size()):
		var p = players[i]
		if is_instance_valid(p):
			var dist = global_position.distance_to(p.global_position)
			#print("[Enemy Debug] Checking player ", i, " at position: ", p.global_position, " | Distance: ", dist)
			if dist < min_distance:
				min_distance = dist
				closest_player = p
				
	target_player = closest_player
	#print("[Enemy Debug] Selected closest target player. Position: ", target_player.global_position)

func pick_new_wander_direction() -> void:
	current_wander_dir = Vector3(
		randf_range(-1.0, 1.0), 
		randf_range(-0.6, 0.6), 
		randf_range(-1.0, 1.0)
	).normalized()

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() and multiplayer.has_multiplayer_peer():
		return

	# Periodically re-evaluate the closest player every 1.0 seconds
	target_refresh_timer -= delta
	if target_refresh_timer <= 0.0 or not target_player or not is_instance_valid(target_player):
		target_refresh_timer = 1.0
		find_player()

	if not target_player:
		return
		
	# ... rest of your movement code ...

	time_passed += delta
	var distance_to_player = global_position.distance_to(target_player.global_position)

	# 1. Aggro Check
	if not is_aggroed:
		if distance_to_player <= aggro_range:
			is_aggroed = true
		else:
			velocity = velocity.move_toward(Vector3.ZERO, speed * delta * 3.0)
			move_and_slide()
			return
	else:
		if distance_to_player > aggro_range * 2.0:
			is_aggroed = false
			return

	# 2. Randomize flight pathing timer
	movement_timer -= delta
	if movement_timer <= 0.0:
		movement_timer = randf_range(1.5, 4.0)
		pick_new_wander_direction()

	# 3. 3D Vector calculations toward player
	var to_player = (target_player.global_position - global_position)
	var dir_to_player = to_player.normalized()

	if distance_to_player > 0.5:
		var look_target = Vector3(target_player.global_position.x, target_player.global_position.y, target_player.global_position.z)
		look_at(look_target, Vector3.UP)

	# 4. Separation Force
	var separation_force := Vector3.ZERO
	for sibling in get_parent().get_children():
		if sibling != self and sibling is CharacterBody3D:
			var dist = global_position.distance_to(sibling.global_position)
			if dist < 2.5 and dist > 0.0: 
				var push_dir = (global_position - sibling.global_position)
				separation_force += push_dir.normalized() / dist

	# 5. Range Band Flight Logic
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

	# 6. Add Natural Buoyancy
	target_velocity.y += sin(time_passed * float_bob_speed) * float_bob_intensity

	# 7. Enforce Limits
	if global_position.y <= min_flight_altitude and target_velocity.y < 0:
		target_velocity.y = 0
	elif global_position.y >= max_flight_altitude and target_velocity.y > 0:
		target_velocity.y = 0

	# 8. Smooth Velocity Interpolation
	velocity.x = move_toward(velocity.x, target_velocity.x, speed * delta * 5.0)
	velocity.y = move_toward(velocity.y, target_velocity.y, speed * delta * 5.0)
	velocity.z = move_toward(velocity.z, target_velocity.z, speed * delta * 5.0)

	move_and_slide()

	move_and_slide()

	if multiplayer.is_server():
		rpc("sync_enemy_transform", global_transform)


@rpc("authority", "unreliable")
func sync_enemy_transform(new_transform: Transform3D) -> void:
	global_transform = new_transform
