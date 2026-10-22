class_name Enemy
extends CharacterBody3D

@export var speed : float
@export var aggro_range : float
@export var min_preferred_distance : float 
@export var max_preferred_distance : float
@export var strafe_speed_multiplier : float
@export var separation_weight : float = 1.0         

@export var max_spawn_distance := 45.0
@export var despawn_distance := 60.0

@export_category("Combat & Health")
@export var max_health: int = 50
@onready var current_health: int = max_health
var is_dead := false

@export_category("Attack Configuration")
@export var attack_range := 2.5             
@export var attack_damage := 10
@export var attack_cooldown := 1.5         
var attack_timer := 0.0

var target_player: Node3D = null
var is_aggroed := false

var movement_timer := 0.0
var current_wander_dir := Vector3.ZERO
var wall_hit_cooldown := 0.0 
var target_refresh_timer := 0.0

# Network sync throttling variables
var sync_timer := 0.0
const SYNC_INTERVAL := 0.05 # 20 updates per second for smooth client updates without packet flooding

func _ready() -> void:
	add_to_group("target")
	
	if multiplayer.is_server():
		await get_tree().physics_frame
		find_player()
		movement_timer = randf_range(1.0, 3.0)
		pick_new_wander_direction()

func find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		target_player = null
		return
		
	var closest_player = players[0]
	var min_distance = global_position.distance_to(closest_player.global_position)
	
	for i in range(1, players.size()):
		var p = players[i]
		if is_instance_valid(p):
			var dist = global_position.distance_to(p.global_position)
			if dist < min_distance:
				min_distance = dist
				closest_player = p
				
	target_player = closest_player

func pick_new_wander_direction() -> void:
	current_wander_dir = Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)).normalized()

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return

	target_refresh_timer -= delta
	if target_refresh_timer <= 0.0 or not target_player or not is_instance_valid(target_player):
		target_refresh_timer = 1.0
		find_player()

	if not target_player:
		return

	# HARDWARE OPTIMIZATION (Distance Culling): Skip heavy AI logic if players are >25m away
	if global_position.distance_to(target_player.global_position) > 25.0:
		return

	if wall_hit_cooldown > 0.0:
		wall_hit_cooldown -= delta
	if attack_timer > 0.0:
		attack_timer -= delta

	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 0

	var distance_to_player = global_position.distance_to(target_player.global_position)

	if not is_aggroed:
		if distance_to_player <= aggro_range:
			is_aggroed = true
		else:
			velocity.x = move_toward(velocity.x, 0, speed * delta * 5.0)
			velocity.z = move_toward(velocity.z, 0, speed * delta * 5.0)
			move_and_slide()
			_try_sync_transform(delta)
			return
	else:
		if distance_to_player > aggro_range * 2.0:
			is_aggroed = false
			_try_sync_transform(delta)
			return

	if distance_to_player <= attack_range:
		if attack_timer <= 0.0:
			perform_attack()
			attack_timer = attack_cooldown

	if distance_to_player > 0.5:
		var look_target = Vector3(target_player.global_position.x, global_position.y, target_player.global_position.z)
		var target_transform = global_transform.looking_at(look_target, Vector3.UP)
		global_transform = global_transform.interpolate_with(target_transform, delta * 12.0)

	movement_timer -= delta
	if movement_timer <= 0.0:
		movement_timer = randf_range(1.5, 4.0)
		pick_new_wander_direction()

	var to_player = (target_player.global_position - global_position)
	to_player.y = 0
	var forward_backward_vector = to_player.normalized()

	var separation_force := Vector3.ZERO
	for sibling in get_parent().get_children():
		if sibling != self and sibling is CharacterBody3D:
			var dist = global_position.distance_to(sibling.global_position)
			if dist < 2.0 and dist > 0.0: 
				var push_dir = (global_position - sibling.global_position)
				push_dir.y = 0
				separation_force += push_dir.normalized() / dist

	var target_velocity: Vector3 = Vector3.ZERO
	if distance_to_player > max_preferred_distance:
		target_velocity = (forward_backward_vector + (current_wander_dir * 0.4) + (separation_force * separation_weight)).normalized() * speed
	elif distance_to_player < min_preferred_distance:
		target_velocity = (-forward_backward_vector + (current_wander_dir * 0.4) + (separation_force * separation_weight)).normalized() * speed
	else:
		target_velocity = (current_wander_dir + (separation_force * separation_weight)).normalized() * (speed * strafe_speed_multiplier)

	velocity.x = move_toward(velocity.x, target_velocity.x, speed * delta * 6.0)
	velocity.z = move_toward(velocity.z, target_velocity.z, speed * delta * 6.0)

	move_and_slide()
	_try_sync_transform(delta)

# THROTTLED NETWORK SYNC
func _try_sync_transform(delta: float) -> void:
	sync_timer += delta
	if sync_timer >= SYNC_INTERVAL:
		sync_timer = 0.0
		rpc("sync_enemy_transform", global_transform)

# VIRTUAL METHOD: Child scripts will override this!
func perform_attack() -> void:
	pass

@rpc("any_peer", "call_local", "reliable")
func receive_damage(amount: int) -> void:
	if not multiplayer.is_server() or is_dead:
		return
	current_health -= amount
	if current_health <= 0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true
	rpc("rpc_client_die")
	if multiplayer.is_server():
		for player in get_tree().get_nodes_in_group("player"):
			if is_instance_valid(player):
				player.rpc("add_experience", 10)
	queue_free()

@rpc("authority", "call_remote", "reliable")
func rpc_client_die() -> void:
	queue_free()

@rpc("authority", "unreliable")
func sync_enemy_transform(new_transform: Transform3D) -> void:
	global_transform = new_transform
