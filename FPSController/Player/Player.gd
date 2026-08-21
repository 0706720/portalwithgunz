extends CharacterBody3D
class_name PlayerCharacter

signal health_changed(health_value)

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
@onready var camera = %Camera3D
@onready var anim_player = $AnimationPlayer
@onready var movement_anim = $MovementAnimationPlayer
@onready var muzzle_flash = $CameraHolder/Camera3D/Pistol/MuzzleFlash
@onready var healthBar = $HUD/healthBar
@onready var raycast = $CameraHolder/Camera3D/RayContainer/RayCast3D
@onready var ray_container = $Camera3D/RayContainer
@onready var rope = Node3D

@export var crouch_anim_player: AnimationPlayer
@export var crouch_shapecast: Node3D
@export_range(5, 10, 0.1)
var crouch_speed : float = 4.0
var _is_crouching: bool = false
var _using_crouch: bool = false

var health = 99
var spread = 10
var knockback_force = 20.0
@onready var anim_playing = false

@export var grapple_speed: float = 25.0
@export var grapple_pull_strength: float = 40.0
@export var max_grapple_distance: float = 50.0
@export var stop_distance: float = 2.0
var is_grappling: bool = false
var grapple_point: Vector3
@export var rope_length = 0.0

var mouse_sensitivity = 0.002
@onready var bulletSpawn = $Head/Camera3D/bulletSpawn
var ammo : int = 5
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
@export var spin_camera_tilt_amount := 360.0   
@export var spin_camera_tilt_speed := 200.0
var current_camera_tilt := 0.0

@onready var state_machine: StateMachine = %StateMachine
@onready var cam_holder = %CameraHolder
var walk_or_run: String = "WalkState"

@export_group("Keybind variables")
@export var move_forward_action: StringName = "play_char_move_forward_action"
@export var move_backward_action: StringName = "play_char_move_backward_action"
@export var move_left_action: StringName = "play_char_move_left_ation"
@export var move_right_action: StringName = "play_char_move_right_action"
@export var run_action: StringName = "play_char_run_action"
@export var crouch_action: StringName = "play_char_crouch_action"
@export var jump_action: StringName = "play_char_jump_action"
@onready var input_actions_list : Array[StringName] = [
	move_forward_action, move_backward_action,
	move_left_action, move_right_action,
	run_action, crouch_action, jump_action
]
@export var check_on_ready_if_inputs_registered : bool = true
var default_input_actions : Dictionary

const LOOK_SPEED = 5
var gravity = 19.6

@export var Portal_one : float
@export var Portal_two : float

var texture = TextureRect

var PortalThrow = preload("res://FPSController/WeaponsManagement/Weapons/portalGunz/throw_portal_gun.tscn")

func _enter_tree():
	print(name)
	set_multiplayer_authority(str(name).to_int())


func _ready():
	Global.players[multiplayer.get_unique_id()] = self
	hit_ground_cooldown_ref = hit_ground_cooldown

	camera.current = is_multiplayer_authority()

	weaponsManager.request_weapon_change(0)

	if is_multiplayer_authority():
		$Player/RightArm.hide()
		$Player/LeftArm.hide()
		$Player/RightLeg.hide()
		$Player/LeftLeg.hide()
		$Player/Body.hide()
		$Player/Head.hide()

	Global.player = self

	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	crouch_shapecast.add_exception($".")
	healthBar.max_value = health
	receive_damage(0)
	randomize()

	build_default_keybinding()
	input_actions_check()


func build_default_keybinding() -> void:
	default_input_actions = {
		move_forward_action : [Key.KEY_W, Key.KEY_UP],
		move_backward_action : [Key.KEY_S, Key.KEY_DOWN],
		move_left_action : [Key.KEY_A, Key.KEY_LEFT],
		move_right_action : [Key.KEY_D, Key.KEY_RIGHT],
		run_action : [Key.KEY_CTRL],
		crouch_action : [Key.KEY_C],
		jump_action : [Key.KEY_SPACE],
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


func _exit_tree() -> void:
	if is_multiplayer_authority():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _unhandled_input(event):
	if not is_multiplayer_authority():
		return

	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * .005)
		camera.rotate_x(-event.relative.y * .005)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

	# shooting, etc. stays local‑only
	if Input.is_action_just_pressed("shoot") \
	and Global.currentWeapon == 'Pistol' \
	and anim_player.current_animation != "shoot":
		play_shoot_effects.rpc()
		if raycast.is_colliding():
			var hit_player = raycast.get_collider()
			if hit_player.is_in_group('Player'):
				hit_player.receive_damage.rpc_id(hit_player.get_multiplayer_authority())
			if hit_player.is_in_group('target'):
				hit_player.delete_target()

	if anim_playing == false and Input.is_action_just_pressed("Fire_shotgun") and Global.currentWeapon == 'Shotgun':
		anim_playing = true
		var shoot_dir = camera.global_transform.basis.z.normalized()
		velocity += shoot_dir * knockback_force
		await get_tree().create_timer(1.0).timeout
		anim_playing = false

func simulate_movement(delta):
	# Local movement (only for the authority of this character)
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
	  
func _physics_process(delta):
	# 1) Local movement for this player only
	simulate_movement(delta)

	# 2) Local camera + input only for the authority
	if is_multiplayer_authority():
		var look_dir = Input.get_vector("look_left", "look_right", "look_up", "look_down")
		if look_dir != Vector2.ZERO:
			rotate_y(-look_dir.x * LOOK_SPEED * delta)
			camera.rotate_x(-look_dir.y * LOOK_SPEED * delta)
			camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)

		# send our state to the other peer
		rpc("_client_sync_state", global_transform, velocity)

		if anim_player.current_animation == "shoot":
			pass
		elif input_direction != Vector2.ZERO and is_on_floor():
			anim_player.play("move")
		else:
			anim_player.play("idle")

		if Input.is_action_just_pressed("Grapple") and Global.currentWeapon == 'GrappleGun':
			start_grapple()

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

		if Input.is_action_just_released("Grapple"):
			stop_grapple()

		if is_grappling:
			process_grapple(delta)

		if Input.is_action_just_pressed("throw"):
			Throw()

		# client → server input
		Network.rpc_id(
			1,
			"server_receive_input",
			multiplayer.get_unique_id(),
			input_direction,
			wish_dir
		)
		
	#EMOTE WHEEL
	var emote = $HUD/SelectionWheel.close()
	
	if is_multiplayer_authority():
		if Input.is_action_just_pressed("emote"):
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			$HUD/SelectionWheel.show()
		if Input.is_action_just_released("emote"):
			$HUD/SelectionWheel.hide()
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			rpc("show_emote_remote", emote)
			show_emote_local(emote)
	
func show_emote_local(emote):
	print(emote)
	match emote:
		1.0:
			$EmoteBar.show()
			$EmoteBar.texture = load("res://assets/images/ThumbsUp.webp")
		2.0:
			pass
		3.0:
			pass
		4.0:
			pass
		5.0:
			pass
		6.0:
			pass
		0:
			pass
	var timer := get_tree().create_timer(2.0)
	timer.timeout.connect(func():
		$EmoteBar.hide()
		$EmoteBar.texture = null
	)

@rpc("any_peer")
func show_emote_remote(emote):
	print(emote)
	match emote:
		1.0:
			$EmoteBar.show()
			$EmoteBar.texture = load("res://assets/images/ThumbsUp.webp")
		2.0:
			pass
	ss	3.0:
			pass
		4.0:
			pass
		5.0:
			pass
		6.0:
			pass
		0:
			pass
	var timer := get_tree().create_timer(2.0)
	timer.timeout.connect(func():
		$EmoteBar.hide()
		$EmoteBar.texture = null
	)


func gravity_apply(delta):
	velocity.y -= gravity * delta

func start_grapple():
	raycast.global_transform = camera.global_transform
	raycast.target_position = Vector3(0, 0, -max_grapple_distance)
	raycast.force_raycast_update()

	if raycast.is_colliding():
		grapple_point = raycast.get_collision_point()
		rope_length = global_transform.origin.distance_to(grapple_point)
		is_grappling = true

func process_grapple(delta):
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_basis = camera.global_transform.basis
	var move_dir = (cam_basis.x * input_dir.x + cam_basis.z * input_dir.y).normalized()
	velocity += move_dir * 10.0 * delta
	var to_grapple = grapple_point - global_transform.origin
	var distance = to_grapple.length()
	var direction = to_grapple.normalized()

	if distance > rope_length:
		var correction = direction * (distance - rope_length)
		velocity += correction * 20.0 * delta

	var velocity_away = velocity.dot(direction)
	if velocity_away > 0:
		velocity -= direction * velocity_away

	velocity += direction * grapple_pull_strength * delta

func stop_grapple():
	is_grappling = false
	velocity *= 1.2

func Throw():
	var PortalgunIns = PortalThrow.instantiate()
	PortalgunIns.position = $CameraHolder/Camera3D/Throwposs.global_position
	get_tree().current_scene.add_child(PortalgunIns)

	var force = -18
	var upDirection = 3.5
	
	var playerRotation = %Camera3D.global_transform.basis.z.normalized()
	
	PortalgunIns.apply_central_impulse(playerRotation * force + Vector3(0, upDirection, 0))

@rpc("call_local")
func play_shoot_effects():
	anim_player.stop()
	anim_player.play("shoot")
	muzzle_flash.restart()
	muzzle_flash.emitting = true

@rpc("authority")
func _client_sync_state(server_transform: Transform3D, server_velocity: Vector3):
	# "server_transform" here is really "other player's transform"
	var current: Transform3D = global_transform
	var target: Transform3D = server_transform

	current.origin = current.origin.lerp(target.origin, POS_SMOOTH)

	var cur_quat: Quaternion = current.basis.get_rotation_quaternion()
	var tgt_quat: Quaternion = target.basis.get_rotation_quaternion()
	var smooth_quat: Quaternion = cur_quat.slerp(tgt_quat, ROT_SMOOTH)
	current.basis = Basis(smooth_quat)

	global_transform = current
	velocity = velocity.lerp(server_velocity, VEL_SMOOTH)


@rpc("any_peer")
func receive_damage(amount):
	health -= amount
	if health <= 0:
		health = 99
		position = Vector3.ZERO
	health_changed.emit(health)


func _on_animation_player_animation_finished(anim_name):
	if anim_name == "shoot":
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


func _process(delta):
	pass


func clip_velocity(normal: Vector3, overbounce : float, delta : float) -> void:
	var backoff := velocity.dot(normal) * overbounce
	if backoff >= 0:
		return

	var change := normal * backoff
	velocity -= change

	var adjust := velocity.dot(normal)
	if adjust < 0.0:
		velocity -= normal * adjust
