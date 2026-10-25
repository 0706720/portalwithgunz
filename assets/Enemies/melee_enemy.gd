class_name MeleeEnemy
extends Enemy

@export_category("Charge Attack")
@export var charge_range: float = 8.0        
@export var charge_speed: float = 28.0      
@export var charge_duration: float = 0.5    
@export var hit_distance_threshold: float = 2.8 # Distance required to score a hit

var is_charging: bool = false
var charge_timer: float = 0.0
var charge_direction: Vector3 = Vector3.ZERO
var has_dealt_damage_this_charge: bool = false

func _ready() -> void:
	super._ready()

func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		super._physics_process(delta) # Allows clients to run base Enemy interpolation!
		return

	if is_dead or not target_player or not is_instance_valid(target_player):
		super._physics_process(delta)
		return

	if is_dead or not target_player or not is_instance_valid(target_player):
		super._physics_process(delta)
		return

	var distance_to_player = global_position.distance_to(target_player.global_position)

	# Handle Charge Movement
	if is_charging:
		charge_timer -= delta
		
		if not is_flying:
			if not is_on_floor():
				velocity.y += get_gravity().y * delta
			else:
				velocity.y = 0
		
		velocity.x = charge_direction.x * charge_speed
		velocity.z = charge_direction.z * charge_speed
		
		# Check for damage if we are close enough during the charge and haven't hit yet
		if not has_dealt_damage_this_charge and distance_to_player <= hit_distance_threshold:
			_apply_charge_damage()

		# End charge if timer runs out
		if charge_timer <= 0.0:
			end_charge()
			
		move_and_slide()
		_try_sync_transform(delta)
		return

	# Trigger a charge if within range and cooldown is ready
	if distance_to_player <= charge_range and attack_timer <= 0.0:
		start_charge()
		return

	super._physics_process(delta)

func start_charge() -> void:
	is_charging = true
	charge_timer = charge_duration
	has_dealt_damage_this_charge = false
	
	var look_target = Vector3(target_player.global_position.x, global_position.y, target_player.global_position.z)
	look_at(look_target, Vector3.UP)
	
	charge_direction = -global_transform.basis.z 
	charge_direction.y = 0
	charge_direction = charge_direction.normalized()
	
	print("[Melee Enemy] Charging at player!")

func end_charge() -> void:
	is_charging = false
	attack_timer = attack_cooldown

func _apply_charge_damage() -> void:
	has_dealt_damage_this_charge = true
	
	var actual_player = target_player
	if actual_player and not actual_player.has_method("take_damage"):
		if actual_player.owner and actual_player.owner.has_method("take_damage"):
			actual_player = actual_player.owner
		elif actual_player.get_parent() and actual_player.get_parent().has_method("take_damage"):
			actual_player = actual_player.get_parent()

	if actual_player and actual_player.has_method("take_damage"):
		actual_player.take_damage(attack_damage)
		print("[Melee Enemy] SUCCESS: Dealt ", attack_damage, " damage to player via charge!")
		end_charge()
