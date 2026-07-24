
extends CharacterBody3D

class_name PlayerCharacter

signal health_changed(health_value)

var current_speed: float

#Movement Variables
@export_group("Movement variables")
var move_speed: float
var move_accel: float
var move_deccel: float
var input_direction: Vector2
var move_direction: Vector3
var desired_move_speed: float
@export var desired_move_speed_curve: Curve #accumulated speed
@export var max_desired_move_speed: float = 30.0
@export var hit_ground_cooldown: float = 0.1 #amount of time the character keep his accumulated speed before losing it (while being on ground)
var hit_ground_cooldown_ref: float

@export_group("Air variables")
var air_speed: float = 500
var air_accel: float = 800
var air_deccel: float = 0
var air_cap: float = 0.85

@export_group("Walk variables")
var walk_speed: float = 9.0
var walk_accel: float = 11.0
var walk_deccel: float = 10.0

#Objects
@onready var weaponsManager = $weaponsManager
@onready var camera = %Camera3D
@onready var anim_player = $AnimationPlayer
@onready var movement_anim = $MovementAnimationPlayer
@onready var muzzle_flash = $CameraHolder/Camera3D/Pistol/MuzzleFlash
@onready var healthBar = $HUD/healthBar
@onready var raycast = $CameraHolder/Camera3D/RayContainer/RayCast3D
@onready var ray_container = $Camera3D/RayContainer
@onready var rope = Node3D

# crouch handlers
@export var crouch_anim_player: AnimationPlayer
@export var crouch_shapecast: Node3D
@export_range(5, 10, 0.1)
# crouch_speed is utilised for animation playback, and the booleans ensure the animation is uninterrupted.
var crouch_speed : float = 4.0
var _is_crouching: bool = false
var _using_crouch: bool = false

#Other
var health = 99
var spread = 10
var knockback_force = 20.0
@onready var anim_playing = false

#grapple hook
@export var grapple_speed: float = 25.0
@export var grapple_pull_strength: float = 40.0
@export var max_grapple_distance: float = 50.0
@export var stop_distance: float = 2.0
var is_grappling: bool = false
var grapple_point: Vector3
@export var rope_length = 0.0
var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

#debug physics code V1
var mouse_sensitivity = 0.002
@onready var bulletSpawn = $Head/Camera3D/bulletSpawn
var ammo : int = 5
var player_health = 100
var canThrow = true
@onready var my_label = $Label
@export var look_sensitivity : float = 0.006
@export var auto_bhop := true

#Physics
@export var sprint_speed := 8.5
@export var ground_accel := 14.0
@export var ground_deccel :=5.0
@export var ground_friction := 5.0
const HEADBOB_MOVE_AMOUNT = 0.06
const HEADBOB_FREQUENCY = 2.4 
var headbob_time := 0.0

#spindash variables
@export var wish_dir := Vector3.ZERO
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

#State Machine
@onready var state_machine: StateMachine = %StateMachine
@onready var cam_holder = %CameraHolder
var walk_or_run: String = "WalkState" #keep in memory if play char was walking or running before being in the air
#for states that require visible changes of the model
@export_group("Keybind variables")
@export var move_forward_action: StringName = "play_char_move_forward_action"
@export var move_backward_action: StringName = "play_char_move_backward_action"
@export var move_left_action: StringName = "play_char_move_left_ation"
@export var move_right_action: StringName = "play_char_move_right_action"
@export var run_action: StringName = "play_char_run_action"
@export var crouch_action: StringName = "play_char_crouch_action"
@export var jump_action: StringName = "play_char_jump_action"
@onready var input_actions_list : Array[StringName] = [move_forward_action, move_backward_action, move_left_action, move_right_action, 
run_action, crouch_action, jump_action]
@export var check_on_ready_if_inputs_registered : bool = true
var default_input_actions : Dictionary
#const SPEED = 10.0
#const JUMP_VELOCITY = 10.0
const LOOK_SPEED = 5 # Adjust as needed for controller comfort
# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = 19.6

#Portal location placeholders
@export var Portal_one : float
@export var Portal_two : float

func _enter_tree():
	print(name)
	set_multiplayer_authority(str(name).to_int())

func _ready():
	hit_ground_cooldown_ref = hit_ground_cooldown
	
	# access the weapons manager script, and call the print function to set the current weapon to pistol
	weaponsManager.print(0)
	if is_multiplayer_authority():
		$Player/RightArm.hide()
		$Player/LeftArm.hide()
		$Player/RightLeg.hide()
		$Player/LeftLeg.hide()
		$Player/Body.hide()
		$Player/Head.hide()
	
	#raycast.add_exception(self)
	Global.player = self
	if not is_multiplayer_authority(): return
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera.current = true
	# ensure collision check ignores player collision shape
	crouch_shapecast.add_exception($".")
	# initialise hp for healthbar
	healthBar.max_value = health
	# call damage to initialise healthbar, initialise max hp
	receive_damage(0)
	randomize()
	
	build_default_keybinding()
	input_actions_check()

func build_default_keybinding() -> void:
	#build it in runtime to ensure that export variables have been set
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
	#check if the input actions written in the editor are the same as the ones registered in the Input map, and if they are written correctly
	#if not, add it to runtime Input map with default keybindings
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
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _unhandled_input(event):
	if not is_multiplayer_authority(): return
	
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * .005)
		camera.rotate_x(-event.relative.y * .005)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
	
	#Shoot
	if Input.is_action_just_pressed("shoot") \
			and Global.currentWeapon == 'Pistol' \
				and anim_player.current_animation != "shoot":
		play_shoot_effects.rpc()
		print('shot occured')
		if raycast.is_colliding():
			var hit_player = raycast.get_collider()
			print('collided')
			if hit_player.is_in_group('Player'):
				hit_player.receive_damage.rpc_id(hit_player.get_multiplayer_authority())
			if hit_player.is_in_group('target'):
				print('recognised target')
				hit_player.delete_target()
	
	#Shotgun
	if anim_playing == false:
		if Input.is_action_just_pressed("Fire_shotgun") and Global.currentWeapon == 'Shotgun':
			anim_playing = true
			print(raycast.is_colliding())
			var shoot_dir = -camera.global_transform.basis.z.normalized()
			velocity += -shoot_dir * knockback_force
			await get_tree().create_timer(1.0).timeout
			anim_playing = false


func _physics_process(delta):
	var input_dir := Input.get_vector("left", "right", "up", "down").normalized()
	wish_dir = self.global_transform.basis * Vector3(input_dir.x, 0., input_dir.y)
	move_and_slide()
	if not is_multiplayer_authority(): return

	# --- New: Handle Camera Look (Right Stick) ---
	# Get the controller stick input (Horizontal and Vertical)
	var look_dir = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	
	if look_dir != Vector2.ZERO:
		# Rotate Player (Yaw) - Horizontal movement of the stick
		rotate_y(-look_dir.x * LOOK_SPEED * delta)
		
		# Rotate Camera (Pitch) - Vertical movement of the stick
		camera.rotate_x(-look_dir.y * LOOK_SPEED * delta)
		
		# Clamp camera pitch rotation (same as your mouse look code)
		camera.rotation.x = clamp(camera.rotation.x, -PI/2, PI/2)
	
	if anim_player.current_animation == "shoot":
		pass
	elif input_dir != Vector2.ZERO and is_on_floor():
		anim_player.play("move")
	else:
		anim_player.play("idle")
	var camera = $Camera3D
	#move_and_slide()
	
	if Input.is_action_just_pressed("Grapple") and Global.currentWeapon == 'GrappleGun':
		start_grapple()
		print("Grapple")
	
	# the 'weapon' checks are just keybinds 1-5 bind to the weapon types. Each call the weapons manager script, and swap out current for new weapon.
	if Input.is_action_just_pressed("weapon1"):
		weaponsManager.print(0)
		
	if Input.is_action_just_pressed("weapon2"):
		weaponsManager.print(1)
		
	if Input.is_action_just_pressed("weapon3"):
		weaponsManager.print(2)
		
	if Input.is_action_just_pressed("weapon4"):
		weaponsManager.print(3)
		
	if Input.is_action_just_pressed("weapon5"):
		weaponsManager.print(4)
		
	if Input.is_action_just_released("Grapple"):
		stop_grapple()
	
	if is_grappling:
		process_grapple(delta)

func gravity_apply(delta):
	self.velocity.y -= gravity * delta

func start_grapple():
	raycast.global_transform = camera.global_transform
	raycast.target_position = Vector3(0, 0, -max_grapple_distance)
	raycast.force_raycast_update()
	print("grapple")
	print(raycast.is_colliding())
	
	if raycast.is_colliding():
		grapple_point = raycast.get_collision_point()
		rope_length = global_transform.origin.distance_to(grapple_point)
		is_grappling = true
		print("elpprag")

func process_grapple(delta):
	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_basis = camera.global_transform.basis
	var move_dir = (cam_basis.x * input_dir.x + cam_basis.z * input_dir.y).normalized()
	velocity += move_dir * 10.0 * delta
	var to_grapple = grapple_point - global_transform.origin
	var distance = to_grapple.length()
	var direction = to_grapple.normalized()

	# --- Keep rope length (constraint) ---
	if distance > rope_length:
		var correction = direction * (distance - rope_length)
		velocity += correction * 20.0 * delta

	# --- Remove velocity going away from grapple ---
	var velocity_away = velocity.dot(direction)
	if velocity_away > 0:
		velocity -= direction * velocity_away

	# --- Add swing pull (tension) ---
	velocity += direction * grapple_pull_strength * delta

func stop_grapple():
	is_grappling = false
	velocity *= 1.2

@rpc("call_local")
func play_shoot_effects():
	anim_player.stop()
	anim_player.play("shoot")
	muzzle_flash.restart()
	muzzle_flash.emitting = true

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
	var max_slope_ang_dot = Vector3(0, 1, 0).rotated(Vector3(1.0, 0, 0), self.floor_max_angle).dot(Vector3(0, 1, 0))
	if normal.dot(Vector3(0, 1, 0)) < max_slope_ang_dot:
		return false
	return false

func _handle_air_physics(delta):
	if is_on_wall():
		if is_surface_too_steep(get_wall_normal()):
			self.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
		else:
			self.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
		clip_velocity(get_wall_normal(), 1, delta) # allows surf

func _process(delta):
	pass

func clip_velocity(normal: Vector3, overbounce : float, delta : float) -> void:
	var backoff := self.velocity.dot(normal) * overbounce
	
	if backoff >= 0: return
	
	var change := normal * backoff
	self.velocity -= change
	
	var adjust := self.velocity.dot(normal)
	if adjust < 0.0:
		self.velocity -= normal * adjust
