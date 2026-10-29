extends CharacterBody3D
class_name PlayerCharacter

signal health_changed(health_value, max_health_value)
static var living_players_count: int = 0
const DEATH_SCREEN_SCENE = preload("res://death_screen.tscn")
var active_death_screen: Node = null
var is_dead: bool = false

var current_speed: float

@export_group("Movement variables")
var move_speed: float
var move_accel: float
var move_deccel: float
var desired_move_speed: float
@export var desired_move_speed_curve: Curve
@export var max_desired_move_speed: float = 30.0
@export var hit_ground_cooldown: float = 0.1
var hit_ground_cooldown_ref: float

const POS_SMOOTH := 0.15
const ROT_SMOOTH := 0.15
const VEL_SMOOTH := 0.20

var wish_dir: Vector3 = Vector3.ZERO
var input_direction: Vector2 = Vector2.ZERO
var move_direction: Vector3 = Vector3.ZERO

@export_group("Air variables")
var air_speed: float = 500
var air_accel: float = 800
var air_deccel: float = 0
var air_cap: float = 0.85

@export_group("Walk variables")
var walk_speed: float = 9.0
var walk_accel: float = 11.0
var walk_deccel: float = 10.0

@onready var weaponsManager = $weaponsManager
@onready var anim_player = $AnimationPlayer
@onready var movement_anim = $MovementAnimationPlayer
@onready var muzzle_flash := $CameraHolder/Camera3D/Pistol/MuzzleFlash
@onready var healthBar = $HUD/healthBar
@onready var raycast := $CameraHolder/Camera3D/RayContainer/RayCast3D
@onready var ray_container := $CameraHolder/Camera3D/RayContainer
@onready var rope = Node3D

@export var crouch_anim_player: AnimationPlayer
@export var crouch_shapecast: Node3D
@export_range(5, 10, 0.1)
var crouch_speed : float = 4.0
var _is_crouching: bool = false
var _using_crouch: bool = false

var health = 99
var max_health = 99
var spread = 10
var knockback_force = -30
var jump_cooldown = 1.0
@onready var anim_playing = false

#@export var grapple_speed: float = 25.0
#@export var grapple_pull_strength: float = 40.0
#@export var max_grapple_distance: float = 50.0
#@export var stop_distance: float = 2.0
#var is_grappling: bool = false
#var grapple_point: Vector3s
#@export var rope_length = 0.0

var mouse_sensitivity = 0.002
@onready var bulletSpawn := $CameraHolder/Camera3D/bulletSpawn
var ammo : int = 5
var pistol_damage = 25
# each stack adds another roll for a 1% chance to deal 4X damage.
var pistol_damage_stacks = 0
var pistol_damage_new = 25
# 5% chance for 5% of players max hp healed if pistol hits a target enemy
var lifesteal = false
var player_health = 100
var canThrow = true
@onready var my_label = $Label
@export var look_sensitivity : float = 0.006
@export var auto_bhop := true

@export var sprint_speed := 8.5
@export var ground_accel := 14.0
@export var ground_deccel :=5.0
@export var ground_friction := 5.0
const HEADBOB_MOVE_AMOUNT = 0.06
const HEADBOB_FREQUENCY = 2.4 
var headbob_time := 0.0

@export var spin_charge_rate := 25.0
@export var spin_max_power := 50.0
@export var spin_min_release := 10.0
@export var spin_friction := 20.0
var spin_charge := 0.0
var is_charging_spin := false
var is_spin_rolling := false
var spin_direction := Vector3.ZERO
@export var spin_cam_tilt_amount := 360.0    
@export var spin_cam_tilt_speed := 200.0
var current_cam_tilt := 0.0

@onready var state_machine: StateMachine = %StateMachine
@onready var cam_holder = %camHolder
var walk_or_run: String = "WalkState"

@export_group("Keybind variables")
@export var move_forward_action: StringName = "play_char_move_forward_action"
@export var move_backward_action: StringName = "play_char_move_backward_action"
@export var move_left_action: StringName = "play_char_move_left_ation"
@export var move_right_action: StringName = "play_char_move_right_action"
@export var run_action: StringName = "play_char_run_action"
@export var crouch_action: StringName = "play_char_crouch_action"
@export var jump_action: StringName = "play_char_jump_action"
@export var throw_action: StringName ="play_char_throw_action"
@onready var input_actions_list : Array[StringName] = [
	move_forward_action, move_backward_action,
	move_left_action, move_right_action,
	run_action, crouch_action, jump_action, throw_action
]
@export var check_on_ready_if_inputs_registered : bool = true
var default_input_actions : Dictionary

const LOOK_SPEED = 5
var gravity = 19.6

@export var Portal_one : float
@export var Portal_two : float

@export var ShotgunBullet:PackedScene

var texture = TextureRect

const PortalThrow: PackedScene = preload("res://FPSController/WeaponsManagement/Weapons/portalGunz/throw_portal_gun.tscn")

@onready var cam := $CameraHolder/Camera3D
# this will be modifed by the upgrades system to ensure that camera is static whilst
# you pick upgrades.
var can_look = true

func _enter_tree():
	print(name)

# ==============================================================================
# UPDATED _ready() FUNCTION
# ==============================================================================
@onready var my_collision_shape: CollisionShape3D = $CollisionShape3D # Adjust if your path is different

func _ready() -> void:
	# Get the correct peer ID for this player node
	var peer_id = name.to_int() if name.is_valid_int() else multiplayer.get_unique_id()
	
	# Register/Update this active player instance in Global
	Global.players[peer_id] = self
	
	# Get this player's actual network owner ID safely
	var owner_id = name.to_int() if name.is_valid_int() else multiplayer.get_unique_id()

	# Tell the server to register this specific peer ID
	if multiplayer.is_server():
		GameManager.register_player(owner_id, self)
	else:
		rpc_id(1, "server_request_register", owner_id)

	# Check if this player instance belongs to the local machine
	if is_multiplayer_authority():
		# Locate the procedural spawn marker in the scene tree
		var scene_root = get_tree().current_scene
		var spawn_point = scene_root.get_node_or_null("RoomContainer/Room_0/SpawnPoints/PlayerSpawn") as Node3D
		
		if spawn_point:
			# Override local transform with the exact position AND facing angle of the marker
			global_transform = spawn_point.global_transform
			
			# Reset velocity to prevent immediate sliding or physics drops
			if "velocity" in self:
				velocity = Vector3.ZERO
				
			print("[Player] Client successfully snapped to Room_0 spawn marker.")
		else:
			push_warning("[Player] Could not locate Room_0 PlayerSpawn marker locally!")

	if my_collision_shape:
		print("[Player Debug] Collision shape node found! Shape asset: ", my_collision_shape.shape)
	else:
		print("[Player Debug] ERROR: Could not find CollisionShape3D node!")
		
	# Make sure both host and client players join the group
	add_to_group("player")
	
	# Convert node name (e.g. "655412542") into integer peer ID authority
	if name.is_valid_int():
		set_multiplayer_authority(name.to_int())

	var local_id := multiplayer.get_unique_id()
	var auth_id := get_multiplayer_authority()

	print("PLAYER READY:", name, " | Local Peer ID:", local_id, " | Node Authority:", auth_id)

	# Safely clear any initial physics velocity to prevent mid-air spawning bugs
	if "velocity" in self:
		velocity = Vector3.ZERO

	if is_multiplayer_authority():
		cam.make_current()
		print("Camera activated locally for peer:", local_id)
		capture_mouse()
		Global.player = self
		
		# Hide local first-person mesh nodes safely
		if has_node("Player/RightArm"): $Player/RightArm.hide()
		if has_node("Player/LeftArm"): $Player/LeftArm.hide()
		if has_node("Player/RightLeg"): $Player/RightLeg.hide()
		if has_node("Player/LeftLeg"): $Player/LeftLeg.hide()
		if has_node("Player/Body"): $Player/Body.hide()
		if has_node("Player/Head"): $Player/Head.hide()
	else:
		cam.current = false
		# Ensure third-person mesh parts are VISIBLE for remote players
		if has_node("Player/RightArm"): $Player/RightArm.show()
		if has_node("Player/LeftArm"): $Player/LeftArm.show()
		if has_node("Player/RightLeg"): $Player/RightLeg.show()
		if has_node("Player/LeftLeg"): $Player/LeftLeg.show()
		if has_node("Player/Body"): $Player/Body.show()
		if has_node("Player/Head"): $Player/Head.show()

	Global.players[auth_id] = self
	hit_ground_cooldown_ref = hit_ground_cooldown

	if weaponsManager and is_multiplayer_authority():
		weaponsManager.request_weapon_change(0)
		
	if crouch_shapecast:
		crouch_shapecast.add_exception(self)
	if healthBar and is_multiplayer_authority():
		healthBar.max_value = health

	build_default_keybinding()
	input_actions_check()

func capture_mouse() -> void:
	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN:
		if is_multiplayer_authority():
			capture_mouse()

func build_default_keybinding() -> void:
	default_input_actions = {
		move_forward_action : [Key.KEY_W, Key.KEY_UP],
		move_backward_action : [Key.KEY_S, Key.KEY_DOWN],
		move_left_action : [Key.KEY_A, Key.KEY_LEFT],
		move_right_action : [Key.KEY_D, Key.KEY_RIGHT],
		run_action : [Key.KEY_CTRL],
		crouch_action : [Key.KEY_C],
		jump_action : [Key.KEY_SPACE],
		throw_action : [Key.KEY_Q]
	}

func input_actions_check() -> void:
	if check_on_ready_if_inputs_registered:
		var registered_input_actions: Array[StringName] = []
		for input_action in InputMap.get_actions():
			if input_action.begins_with(&"play_char_"):
				registered_input_actions.append(input_action)

		for input_action in input_actions_list:
			if input_action == &"":
				assert(false, "There's an undefined input action")

			if not registered_input_actions.has(input_action):
				var key_names = default_input_actions[input_action].map(func(key):
					return OS.get_keycode_string(key)
				)

				push_warning("'{input}' missing in InputMap, or input action wrongly named in the editor.\nAdding the '{input}' to runtime InputMap temporarily with the key/s: {keys}"
				.format({"input": input_action, "keys": String(", ").join(key_names)}))

				InputMap.add_action(input_action)
				for keycode in default_input_actions[input_action]:
					var input_event_key = InputEventKey.new()
					input_event_key.physical_keycode = keycode
					InputMap.action_add_event(input_action, input_event_key)

func _unhandled_input(event):
	if not is_multiplayer_authority():
		return

	if event is InputEventMouseMotion and can_look:
		rotate_y(-event.relative.x * .005)
		cam.rotate_x(-event.relative.y * .005)
		cam.rotation.x = clamp(cam.rotation.x, -PI/2, PI/2)

	if is_multiplayer_authority() and weaponsManager:
		var active_weapon = weaponsManager.get("current_weapon_name")
		if Input.is_action_just_pressed("shoot") \
		and active_weapon == 'Pistol' \
		and anim_player.current_animation != "shoot":
			play_shoot_effects.rpc()
			
			if raycast.is_colliding():
				var collider = raycast.get_collider()
				var enemy_target = null
				
				if collider:
					if collider.has_method("receive_damage"):
						enemy_target = collider
					elif collider.owner and collider.owner.has_method("receive_damage"):
						enemy_target = collider.owner
					elif collider.get_parent() and collider.get_parent().has_method("receive_damage"):
						enemy_target = collider.get_parent()
				
				if enemy_target and enemy_target.is_in_group('target'):
					check_extra_damage()
					check_lifesteal()
					# Send integer peer_id instead of Node instance 'self'
					enemy_target.rpc_id(1, "receive_damage", pistol_damage_new, multiplayer.get_unique_id())

	if anim_playing == false and Input.is_action_just_pressed("superjump") and Global.jump_unlocked:
		anim_playing = true
		var shoot_dir = cam.global_transform.basis.z.normalized()
		velocity += shoot_dir * knockback_force
		await get_tree().create_timer(jump_cooldown).timeout
		anim_playing = false

func simulate_movement(delta):
	if is_multiplayer_authority():
		input_direction = Input.get_vector(
			move_left_action,
			move_right_action,
			move_forward_action,
			move_backward_action
		).normalized()

		if input_direction != Vector2.ZERO:
			move_direction = (global_transform.basis * Vector3(input_direction.x, 0.0, input_direction.y)).normalized()
		else:
			move_direction = Vector3.ZERO

		wish_dir = move_direction

		if state_machine:
			state_machine.physics_update(delta)
		else:
			velocity = wish_dir * move_speed
			
		move_and_slide()

# ==============================================================================
# UPDATED _physics_process() FUNCTION
# ==============================================================================
func _physics_process(delta):
	# NON-AUTHORITY CLIENTS ONLY: Skip processing local inputs/HUD on unowned avatars
	if not is_multiplayer_authority():
		return

	# 1) Local movement execution
	simulate_movement(delta)

	# 2) Local camera keyboard rotation
	var look_dir = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if look_dir != Vector2.ZERO and can_look:
		rotate_y(-look_dir.x * LOOK_SPEED * delta)
		cam.rotate_x(-look_dir.y * LOOK_SPEED * delta)
		cam.rotation.x = clamp(cam.rotation.x, -PI/2, PI/2)

	# Broadcast state sync
	rpc("_client_sync_state", global_transform, velocity)

	if anim_player.current_animation == "shoot":
		pass
	elif input_direction != Vector2.ZERO and is_on_floor():
		anim_player.play("move")
	else:
		anim_player.play("idle")

	#if Input.is_action_just_pressed("Grapple") and Global.currentWeapon == 'GrappleGun':
		#start_grapple()

	if Input.is_action_just_pressed("weapon1"):
		weaponsManager.request_weapon_change(0)
	if Input.is_action_just_pressed("weapon2"):
		weaponsManager.request_weapon_change(1)
	if Input.is_action_just_pressed("weapon3"):
		weaponsManager.request_weapon_change(2)
	if Input.is_action_just_pressed("weapon4"):
		weaponsManager.request_weapon_change(3)
	if Input.is_action_just_pressed("weapon5"):
		weaponsManager.request_weapon_change(4)

	#if Input.is_action_just_released("Grapple"):
		#stop_grapple()
#
	#if is_grappling:
		#process_grapple(delta)

	if Input.is_action_just_pressed(throw_action):
		throw_weapon()

	# EMOTE WHEEL
	#var emote = $HUD/SelectionWheel.close()
	#if Input.is_action_just_pressed("emote"):
		#Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		#$HUD/SelectionWheel.show()
	#if Input.is_action_just_released("emote"):
		#$HUD/SelectionWheel.hide()
		#Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		#rpc("show_emote_remote", emote)
		#show_emote_local(emote)
#
#func show_emote_local(emote):
	#print(emote)
	#match emote:
		#1.0:
			#$EmoteBar.show()
			#$EmoteBar.texture = load("res://assets/images/ThumbsUp.webp")
		#2.0:
			#$EmoteBar.show()
			#$EmoteBar.texture = load("res://assets/images/Pelican.jpeg")
		#3.0:
			#$EmoteBar.show()
			#$EmoteBar.texture = load("res://assets/images/8880154.jpg")
		#4.0:
			#$EmoteBar.show()
			#$EmoteBar.texture = load("res://assets/images/give-me-your-favorite-reaction-memes-v0-je7aot4ib6qe1.webp")
		#5.0:
			#$EmoteBar.show()
			#$EmoteBar.texture = load("res://assets/images/mort-meme.png")
		#6.0:
			#$EmoteBar.show()
			#$EmoteBar.texture = load("res://assets/images/chicken-rice-and-yoghurt-v0-7ria5b8ongi41.webp")
		#0:
			#pass
	#var timer := get_tree().create_timer(2.0)
	#timer.timeout.connect(func():
		#$EmoteBar.hide()
		#$EmoteBar.texture = null
	#)

@rpc("any_peer")
func show_emote_remote(emote):
	print(emote)
	match emote:
		1.0:
			$EmoteBar.show()
			$EmoteBar.texture = load("res://assets/images/ThumbsUp.webp")
		2.0:
			$EmoteBar.show()
			$EmoteBar.texture = load("res://assets/images/Pelican.jpeg")
		3.0:
			$EmoteBar.show()
			$EmoteBar.texture = load("res://assets/images/8880154.jpg")
		4.0:
			$EmoteBar.show()
			$EmoteBar.texture = load("res://assets/images/give-me-your-favorite-reaction-memes-v0-je7aot4ib6qe1.webp")
		5.0:
			$EmoteBar.show()
			$EmoteBar.texture = load("res://assets/images/mort-meme.png")
		6.0:
			$EmoteBar.show()
			$EmoteBar.texture = load("res://assets/images/chicken-rice-and-yoghurt-v0-7ria5b8ongi41.webp")
		0:
			pass
	var timer := get_tree().create_timer(2.0)
	timer.timeout.connect(func():
		$EmoteBar.hide()
		$EmoteBar.texture = null
	)



func gravity_apply(delta):
	velocity.y -= gravity * delta

#func start_grapple():
	#raycast.global_transform = cam.global_transform
	#raycast.target_position = Vector3(0, 0, -max_grapple_distance)
	#raycast.force_raycast_update()
	#if raycast.is_colliding():
		#grapple_point = raycast.get_collision_point()
		#rope_length = global_transform.origin.distance_to(grapple_point)
		#is_grappling = true
#
#func process_grapple(delta):
	#var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	#var cam_basis = cam.global_transform.basis
	#var move_dir = (cam_basis.x * input_dir.x + cam_basis.z * input_dir.y).normalized()
	#velocity += move_dir * 10.0 * delta
	#var to_grapple = grapple_point - global_transform.origin
	#var distance = to_grapple.length()
	#var direction = to_grapple.normalized()
#
	#if distance > rope_length:
		#var correction = direction * (distance - rope_length)
		#velocity += correction * 20.0 * delta
#
	#var velocity_away = velocity.dot(direction)
	#if velocity_away > 0:
		#velocity -= direction * velocity_away
#
	#velocity += direction * grapple_pull_strength * delta
#
#func stop_grapple():
	#is_grappling = false
	#velocity *= 1.2

func throw_weapon():
	print("func_weapon called")
	request_spawn_projectile.rpc_id(1, global_position)

@rpc("any_peer", "reliable")
func request_spawn_projectile(spawn_position: Vector2):
	if multiplayer.is_server():
		print("Server: Spawning weapon at ", spawn_position)
		var PortalgunIns = PortalThrow.instantiate()
		PortalgunIns.global_position = spawn_position
		if has_node("Throw_portal_gun"):
			get_node("Throw_portal_gun").add_child(PortalgunIns)

@rpc("call_local")
func play_shoot_effects():
	anim_player.stop()
	anim_player.play("shoot")
	muzzle_flash.restart()
	muzzle_flash.emitting = true

@rpc("any_peer", "unreliable")
func _client_sync_state(server_transform: Transform3D, server_velocity: Vector3):
	# Interpolate remote character transforms on other peer screens
	if not is_multiplayer_authority():
		var current: Transform3D = global_transform
		current.origin = current.origin.lerp(server_transform.origin, POS_SMOOTH)

		var cur_quat: Quaternion = current.basis.get_rotation_quaternion()
		var tgt_quat: Quaternion = server_transform.basis.get_rotation_quaternion()
		var smooth_quat: Quaternion = cur_quat.slerp(tgt_quat, ROT_SMOOTH)
		current.basis = Basis(smooth_quat)

		global_transform = current
		velocity = velocity.lerp(server_velocity, VEL_SMOOTH)

# ==============================================================================
# SECURE HEALTH & DAMAGE SYSTEM
# ==============================================================================

func take_damage(amount: int) -> void:
	if not multiplayer.is_server() or is_dead:
		return
		
	print("[Damage] Health is: ", health, " | is_dead: ", is_dead)
		
	health = clamp(health - amount, 0, max_health)
	rpc("client_update_health", health, max_health)
	
	if health <= 0:
		server_handle_player_death()

@rpc("any_peer", "call_local", "reliable")
func client_update_health(new_health: int, new_max_health: int) -> void:
	health = new_health
	max_health = new_max_health
	health_changed.emit(health, max_health)

func server_handle_player_death() -> void:
	if not multiplayer.is_server(): return
	if is_dead: return
		
	# Notify GameManager of death
	var peer_id: int = name.to_int() if name.is_valid_int() else multiplayer.get_unique_id()
	GameManager.on_player_death(peer_id)
	rpc("handle_local_death")

@rpc("any_peer", "call_local", "reliable")
func change_max_hp(amount: int) -> void:
	if not multiplayer.is_server():
		return
	max_health += int(amount)
	health = clamp(health + amount, 0, max_health)
	rpc("client_update_health", health, max_health)

@rpc("any_peer", "reliable")
func server_request_register(peer_id: int) -> void:
	if multiplayer.is_server():
		GameManager.register_player(peer_id, self)

@rpc("any_peer", "call_local", "reliable")
func handle_local_death() -> void:
	print("[Player] Handling death for peer: ", name)
	
	is_dead = true
	
	global_transform.origin = Vector3(0, -999, 0)
	velocity = Vector3.ZERO
	
	if has_node("CollisionShape3D"):
		$CollisionShape3D.disabled = true
	set_process(false)
	set_physics_process(false)
	
	if name.to_int() == multiplayer.get_unique_id():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
		# Only instantiate if one isn't already active
		if not active_death_screen:
			active_death_screen = DEATH_SCREEN_SCENE.instantiate()
			if get_tree().current_scene:
				get_tree().current_scene.add_child(active_death_screen)

# 1. Allows the server to tell this specific client to clear their death screen
@rpc("authority", "call_local", "reliable")
func rpc_clear_death_screen() -> void:
	print("[Player] Clearing death screen locally for peer: ", name)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED # Change this to your game's normal active mouse mode (e.g., MOUSE_MODE_VISIBLE if you use a cursor)
	
	if active_death_screen and is_instance_valid(active_death_screen):
		active_death_screen.queue_free()
		active_death_screen = null

@rpc("any_peer", "call_local", "reliable")
func client_revive_player(target_tf: Transform3D) -> void:
	print("[Player] Locally reviving, repositioning, and restoring controls for: ", name)
	is_dead = false
	
	# 1. Force position and zero momentum FIRST before turning physics back on
	global_transform = target_tf
	if self is CharacterBody3D:
		velocity = Vector3.ZERO
		
	# 2. Re-enable collisions & processing AFTER position is set
	var col_shape = get_node_or_null("CollisionShape3D")
	if col_shape:
		col_shape.disabled = false
		
	set_process(true)
	set_physics_process(true)
	
	# 3. Only lock mouse and clear UI for the LOCAL player
	if name.to_int() == multiplayer.get_unique_id():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
		if active_death_screen and is_instance_valid(active_death_screen):
			active_death_screen.queue_free()
			active_death_screen = null

func _exit_tree() -> void:
	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		# Clean up count if a player abruptly disconnects mid-game
	if multiplayer.is_server() and health > 0:
		living_players_count = max(0, living_players_count - 1)

func _on_animation_player_animation_finished(anim_name):
	if anim_name == "shoot" and crouch_anim_player:
		crouch_anim_player.play("idle")

func is_surface_too_steep(normal : Vector3) -> bool:
	var max_slope_ang_dot = Vector3(0, 1, 0).rotated(Vector3(1.0, 0, 0), floor_max_angle).dot(Vector3(0, 1, 0))
	if normal.dot(Vector3(0, 1, 0)) < max_slope_ang_dot:
		return false
	return false

func _handle_air_physics(delta):
	if is_on_wall():
		if is_surface_too_steep(get_wall_normal()):
			motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
		else:
			motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
		clip_velocity(get_wall_normal(), 1, delta)

func clip_velocity(normal: Vector3, overbounce : float, delta : float) -> void:
	var backoff := velocity.dot(normal) * overbounce
	if backoff >= 0:
		return

	var change := normal * backoff
	velocity -= change

	var adjust := velocity.dot(normal)
	if adjust < 0.0:
		velocity -= normal * adjust

func scale_grenade(scale_factor: int):
	var grenade = get_node("res://grenade.tscn")
	grenade.scale = Vector3.ONE * 5.0

@rpc("authority", "call_local", "reliable")
func add_experience(amount: int) -> void:
	if not multiplayer.is_server():
		return
	Global.experience_up.emit(amount)
	
func check_extra_damage():
	# reset dmg to base
	pistol_damage_new = pistol_damage
	if pistol_damage_stacks == 0:
		return
	# loop for while loop happens exactly how many cards you have
	var loops = pistol_damage_stacks
	while loops > 0:
		# 1 in 100
		var num = randi_range(1, 100)
		if num == 1:
			pistol_damage_new = pistol_damage * 4
			print("this has hit")
			break
		loops -= 1

func check_lifesteal():
	if lifesteal == false:
		return
	var num = randi_range(1, 20)
	if num == 1:
		take_damage(-5)
