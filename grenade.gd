extends RigidBody3D

@export var explosion_power: float = 10.0
@export var explosion_damage: float = 50.0
@onready var explosion_area: Area3D = $Area3D
@onready var debris: GPUParticles3D = $Grenade_explosion/Debris2
@onready var smoke: GPUParticles3D = $Grenade_explosion/Smoke2
@onready var fire: GPUParticles3D = $Grenade_explosion/Fire2
@onready var grenade_body = $MeshInstance3D 
@onready var grenade_top = %MeshInstance3D2
@onready var grenade_tab = %MeshInstance3D3

var has_exploded := false

func _ready() -> void:
	$Timer.timeout.connect(_on_timer_timeout)
	
	# Enable contact monitoring so RigidBody3D can detect collisions
	contact_monitor = true
	max_contacts_reported = 4
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
		
	print("grenade _ready scale:", scale)

func _process(delta: float) -> void:
	pass

# Triggered when the RigidBody3D collides with anything in the world
func _on_body_entered(body: Node3D) -> void:
	if has_exploded:
		return
		
	# Check if it hit an enemy or something in the target group
	if body.is_in_group("Enemy") or body is CharacterBody3D:
		explode()

func _on_timer_timeout() -> void:
	explode()

func explode() -> void:
	if has_exploded:
		return
	has_exploded = true
	
	freeze = true
	if grenade_body:
		grenade_body.visible = false
	if grenade_tab:
		grenade_tab.visible = false
	if grenade_top:
		grenade_top.visible = false
	$CollisionShape3D.disabled = true
	$CollisionShape3D2.disabled = true
	$CollisionShape3D3.disabled = true
	
	var overlapping_bodies = explosion_area.get_overlapping_bodies()
	for body in overlapping_bodies:
		if body.is_in_group('Enemy'):
			if body.has_method("receive_damage"):
				body.receive_damage.rpc(50)
		if body is RigidBody3D and body != self:
			var force_dir = (body.global_position - global_position).normalized()
			body.apply_central_impulse(force_dir * explosion_power)
			
	debris.emitting = true
	smoke.emitting = true
	fire.emitting = true
	await get_tree().create_timer(2.0).timeout
	queue_free()
