extends CharacterBody3D

@export var speed : float
@export var aggro_range : float

@export var min_preferred_distance : float 
@export var max_preferred_distance : float

@export var strafe_speed_multiplier : float
@export var separation_weight : float        

var target_player: Node3D = null
var is_aggroed := false

# Randomized movement variables
var movement_timer := 0.0
var current_wander_dir := Vector3.ZERO
var wall_hit_cooldown := 0.0 

func _ready() -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		set_physics_process(false)
		return

	await get_tree().physics_frame
	find_player()
	# Randomize initial timer so enemies don't sync up on spawn
	movement_timer = randf_range(1.0, 3.0)
	pick_new_wander_direction()

func find_player() -> void:
	target_player = get_tree().get_first_node_in_group("player")

func pick_new_wander_direction() -> void:
	# Pick a random movement blend (mix of forward/backward and sideways angles)
	var random_angle = randf_range(-PI / 2.0, PI / 2.0) # Varies between hard left/right and diagonal forward/back
	var base_dir = Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)).normalized()
	current_wander_dir = base_dir

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server() and multiplayer.has_multiplayer_peer():
		return

	if not target_player or not is_instance_valid(target_player):
		find_player()
		return

	if wall_hit_cooldown > 0.0:
		wall_hit_cooldown -= delta

	# 1. Apply gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0

	# 2. Check distance to player for aggro
	var distance_to_player = global_position.distance_to(target_player.global_position)

	if not is_aggroed:
		if distance_to_player <= aggro_range:
			is_aggroed = true
		else:
			velocity.x = move_toward(velocity.x, 0, speed * delta * 5.0)
			velocity.z = move_toward(velocity.z, 0, speed * delta * 5.0)
			move_and_slide()
			return
	else:
		if distance_to_player > aggro_range * 2.0:
			is_aggroed = false
			return

	# 3. Randomize movement intent timer (variable timing)
	movement_timer -= delta
	if movement_timer <= 0.0:
		movement_timer = randf_range(1.5, 4.0) # Random duration for this behavior state
		pick_new_wander_direction()

	# 4. Core vectors toward the player
	var to_player = (target_player.global_position - global_position)
	to_player.y = 0
	var forward_backward_vector = to_player.normalized()

	# Smooth look at player
	if distance_to_player > 0.5:
		var look_target = Vector3(target_player.global_position.x, global_position.y, target_player.global_position.z)
		look_at(look_target, Vector3.UP)

	# 5. Separation Force
	var separation_force := Vector3.ZERO
	for sibling in get_parent().get_children():
		if sibling != self and sibling is CharacterBody3D:
			var dist = global_position.distance_to(sibling.global_position)
			if dist < 2.0 and dist > 0.0: 
				var push_dir = (global_position - sibling.global_position)
				push_dir.y = 0
				separation_force += push_dir.normalized() / dist

	# 6. Dynamic Range Band & Organic Wandering Logic
	var target_velocity := Vector3.ZERO

	if distance_to_player > max_preferred_distance:
		# Too far: Strongly chase player, mixed with slight organic weaving
		var final_move_dir = (forward_backward_vector + (current_wander_dir * 0.4) + (separation_force * separation_weight)).normalized()
		target_velocity = final_move_dir * speed
		
	elif distance_to_player < min_preferred_distance:
		# Too close: Strongly back away, mixed with organic weaving
		var final_move_dir = (-forward_backward_vector + (current_wander_dir * 0.4) + (separation_force * separation_weight)).normalized()
		target_velocity = final_move_dir * speed
		
	else:
		# INSIDE THE 10-20 "SWEET SPOT": Organic free-roam weaving
		# They drift back and forth, side to side, maintaining the range band dynamically.
		var final_move_dir = (current_wander_dir + (separation_force * separation_weight)).normalized()
		target_velocity = final_move_dir * (speed * strafe_speed_multiplier)

	# 7. Smooth velocity interpolation
	velocity.x = move_toward(velocity.x, target_velocity.x, speed * delta * 6.0)
	velocity.z = move_toward(velocity.z, target_velocity.z, speed * delta * 6.0)

	move_and_slide()

	# 8. Wall collision unstick handler
	if get_slide_collision_count() > 0 and wall_hit_cooldown <= 0.0:
		for i in range(get_slide_collision_count()):
			var collision = get_slide_collision(i)
			if collision.get_collider() is not CharacterBody3D:
				pick_new_wander_direction() # Pick a completely new random direction to escape the wall
				wall_hit_cooldown = 0.5 
				break
