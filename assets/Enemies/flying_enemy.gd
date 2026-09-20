extends CharacterBody3D

@export var speed := 3.0
@export var aggro_range := 30.0         

# 3D Range Band for distance tracking
@export var min_preferred_distance := 8.0   
@export var max_preferred_distance := 18.0   

# Altitude Boundaries (Global Y-axis limits)
@export var min_flight_altitude := 1.5   # Lowest the enemy can fly
@export var max_flight_altitude := 7.0   # Highest the enemy can fly

@export var separation_weight := 1.5        
@export var float_bob_speed := 3.0       # Speed of natural floating sine wave
@export var float_bob_intensity := 0.4   # Amplitude of floating bobble

var target_player: Node3D = null
var is_aggroed := false

var movement_timer := 0.0
var current_wander_dir := Vector3.ZERO
var time_passed := 0.0

func _ready() -> void:
	# Server-side execution check for multiplayer consistency
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		set_physics_process(false)
		return

	await get_tree().physics_frame
	find_player()
	movement_timer = randf_range(1.0, 3.0)
	pick_new_wander_direction()

func find_player() -> void:
	target_player = get_tree().get_first_node_in_group("player")

func pick_new_wander_direction() -> void:
	# Pick random 3D offsets for organic floating maneuvers
	current_wander_dir = Vector3(
		randf_range(-1.0, 1.0), 
		randf_range(-0.6, 0.6), 
		randf_range(-1.0, 1.0)
	).normalized()

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() and multiplayer.has_multiplayer_peer():
		return

	if not target_player or not is_instance_valid(target_player):
		find_player()
		return

	time_passed += delta
	var distance_to_player = global_position.distance_to(target_player.global_position)

	# 1. Aggro Check
	if not is_aggroed:
		if distance_to_player <= aggro_range:
			is_aggroed = true
		else:
			# Gently hover in place when idle
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

	# Smoothly look at the player
	if distance_to_player > 0.5:
		var look_target = Vector3(target_player.global_position.x, target_player.global_position.y, target_player.global_position.z)
		look_at(look_target, Vector3.UP)

	# 4. Separation Force (Prevent flying enemies from clumping together)
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
		# Too far: Fly closer while weaving and separating
		var final_dir = (dir_to_player + (current_wander_dir * 0.4) + (separation_force * separation_weight)).normalized()
		target_velocity = final_dir * speed
		
	elif distance_to_player < min_preferred_distance:
		# Too close: Back away while weaving
		var final_dir = (-dir_to_player + (current_wander_dir * 0.4) + (separation_force * separation_weight)).normalized()
		target_velocity = final_dir * speed
		
	else:
		# Sweet spot: Hover freely around the player
		var final_dir = (current_wander_dir + (separation_force * separation_weight)).normalized()
		target_velocity = final_dir * (speed * 0.7)

	# 6. Add Natural Buoyancy (Sine wave vertical bobble)
	target_velocity.y += sin(time_passed * float_bob_speed) * float_bob_intensity

	# 7. Enforce Maximum/Minimum Flight Altitude Limits
	if global_position.y <= min_flight_altitude and target_velocity.y < 0:
		target_velocity.y = 0
	elif global_position.y >= max_flight_altitude and target_velocity.y > 0:
		target_velocity.y = 0

	# 8. Smooth Velocity Interpolation (Prevents twitching)
	velocity.x = move_toward(velocity.x, target_velocity.x, speed * delta * 5.0)
	velocity.y = move_toward(velocity.y, target_velocity.y, speed * delta * 5.0)
	velocity.z = move_toward(velocity.z, target_velocity.z, speed * delta * 5.0)

	move_and_slide()
