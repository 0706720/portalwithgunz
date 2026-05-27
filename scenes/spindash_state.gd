extends State

class_name SpindashState

var state_name : String = "Spindash"
var play_char : CharacterBody3D
var wish_dir := Vector3.ZERO
@export var spin_charge_rate := 75.0
@export var spin_max_power := 100.0
@export var spin_min_release := 10.0
@export var spin_friction := 20.0
var spin_charge := 0.0
var is_charging_spin := false
var is_spin_rolling := false
var spin_direction := Vector3.ZERO

func enter(play_char_ref : CharacterBody3D):
	#pass the play char refrence 
	play_char = play_char_ref
	
	verifications()
	
	print("Entered Spindash")
func verifications():
	pass

func physics_update(delta : float):
	applies(delta)
	
	#play_char.gravity_apply(delta)
	
	input_management()
	
	move(delta)

func applies(delta : float):
	if Input.is_action_just_released("spin_dash"):
		if play_char.is_on_floor():
			if play_char.move_direction: transitioned.emit(self, play_char.walk_or_run)
			else: transitioned.emit(self, "IdleState")

func input_management():
	pass

func move(delta : float):
	if play_char.is_on_floor():
		if Input.is_action_pressed("spin_dash") and !is_spin_rolling:
			is_charging_spin = true
			spin_direction = -play_char.global_transform.basis.z.normalized()
			spin_charge += spin_charge_rate * delta
			spin_charge = clamp(spin_charge, 0.0, spin_max_power)
		if is_charging_spin and Input.is_action_just_released("spin_dash"):
			if spin_charge > spin_min_release:
				play_char.velocity = spin_direction * spin_charge
				is_spin_rolling = true
			spin_charge = 0.0
			is_charging_spin = false
		if !is_charging_spin and !is_spin_rolling:
			play_char._handle_ground_physics(delta)
	else:
		play_char._handle_air_physics(delta)
	if is_spin_rolling:
		var horizontal_vel = Vector3(play_char.velocity.x, 0, play_char.velocity.z)
		var speed = horizontal_vel.length()
		if speed > 0:
			speed = move_toward(speed, 0.0, spin_friction * delta)
			horizontal_vel = horizontal_vel.normalized() * speed
			play_char.velocity.x = horizontal_vel.x
			play_char.velocity.z = horizontal_vel.z
			print(is_spin_rolling)
		if speed < 1:
			is_spin_rolling = false
