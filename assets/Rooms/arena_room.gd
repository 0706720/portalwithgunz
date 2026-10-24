extends Node3D

@export var total_waves: int = 3
@export var door_collisions: Array[Node3D] # Accepts StaticBody3D, Area3D, or generic Node3D containers!

@onready var activation_area: Area3D = get_node_or_null("ActivationArea")

var current_wave: int = 0
var active_enemies_count: int = 0
var room_activated: bool = false
var enemy_waves: Array[Array] = []

func _ready() -> void:
	if activation_area:
		if not activation_area.body_entered.is_connected(_on_activation_area_body_entered):
			activation_area.body_entered.connect(_on_activation_area_body_entered)
			
	# Initialize doors to start open/disabled before the arena triggers
	for door in door_collisions:
		if is_instance_valid(door):
			door.hide()
			_set_door_collision_state(door, true) # true = disabled (open)

func initialize_arena(enemy_data_list: Array[Dictionary]) -> void:
	if enemy_data_list.is_empty():
		return
		
	enemy_waves.clear()
	var enemies_per_wave = ceili(float(enemy_data_list.size()) / float(total_waves))
	
	for i in range(0, enemy_data_list.size(), enemies_per_wave):
		var wave_slice = enemy_data_list.slice(i, i + enemies_per_wave)
		enemy_waves.append(wave_slice)

func _on_activation_area_body_entered(body: Node3D) -> void:
	if not multiplayer.is_server(): return
	if room_activated: return
	if not body.is_in_group("player"): return
	
	room_activated = true
	if activation_area:
		activation_area.set_deferred("monitoring", false)
		
	lock_room()
	start_next_wave()

func lock_room() -> void:
	rpc("client_lock_room")

@rpc("authority", "call_local", "reliable")
func client_lock_room() -> void:
	for door in door_collisions:
		if is_instance_valid(door):
			door.show()
			_set_door_collision_state(door, false) # false = enabled (blocking)
	print("[Arena] Room locked! All exits blocked. Wave 1 incoming.")

func start_next_wave() -> void:
	if not multiplayer.is_server():
		return
		
	if current_wave >= enemy_waves.size():
		complete_arena()
		return
		
	current_wave += 1
	print("[Arena] Starting Wave: ", current_wave)
	
	var current_wave_enemies = enemy_waves[current_wave - 1]
	active_enemies_count = current_wave_enemies.size()
	
	for enemy_data in current_wave_enemies:
		var scene = load(enemy_data["path"]) as PackedScene
		if scene:
			var enemy = scene.instantiate() as Node3D
			if enemy.has_method("initialize_scaled_stats"):
				enemy.initialize_scaled_stats(enemy_data["multiplier"])
			
			add_child(enemy)
			
			var safe_tf = enemy_data["transform"]
			safe_tf.origin.y += 0.3
			enemy.global_transform = safe_tf
			
			if enemy.has_method("set_initial_network_transform"):
				enemy.set_initial_network_transform(safe_tf)
				
			enemy.add_to_group("network_enemies")
			
			if enemy.has_method("set_arena_manager"):
				enemy.set_arena_manager(self)
				
			rpc("rpc_spawn_arena_enemy_remote", enemy_data["path"], safe_tf, enemy_data["multiplier"])

@rpc("authority", "call_remote", "reliable")
func rpc_spawn_arena_enemy_remote(e_path: String, tf: Transform3D, multiplier: float) -> void:
	var scene = load(e_path) as PackedScene
	if scene:
		var enemy = scene.instantiate() as Node3D
		if enemy.has_method("initialize_scaled_stats"):
			enemy.initialize_scaled_stats(multiplier)
		add_child(enemy)
		enemy.global_transform = tf
		if enemy.has_method("set_initial_network_transform"):
			enemy.set_initial_network_transform(tf)
		enemy.add_to_group("network_enemies")

func unregister_enemy() -> void:
	if not multiplayer.is_server():
		return
		
	active_enemies_count -= 1
	print("[Arena] Enemy defeated. Remaining in wave: ", active_enemies_count)
	
	if active_enemies_count <= 0:
		await get_tree().create_timer(1.5).timeout
		start_next_wave()

func complete_arena() -> void:
	print("[Arena] All waves cleared! Unlocking arena.")
	rpc("client_unlock_room")

@rpc("authority", "call_local", "reliable")
func client_unlock_room() -> void:
	for door in door_collisions:
		if is_instance_valid(door):
			door.queue_free() # Deletes the blocking door objects entirely when cleared

# Helper function using set_deferred to safely toggle collision shapes without physics race conditions
func _set_door_collision_state(parent_node: Node, disabled_state: bool) -> void:
	for child in parent_node.get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", disabled_state)
		elif child.get_child_count() > 0:
			_set_door_collision_state(child, disabled_state)
