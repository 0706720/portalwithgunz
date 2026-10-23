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

# Called when the node enters the scene tree for the fssirst time.
func _ready() -> void:
	$Timer.timeout.connect(_on_timer_timeout)
	print("grenade _ready scale:", scale)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_timer_timeout() -> void:
	explode()

func explode() -> void:
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
		if body.is_in_group('target'):
				# If the enemy has a receive_damage function, call it via RPC (passing damage amount, e.g., 25)
				if body.has_method("receive_damage"):
					body.receive_damage.rpc(25)
		if body is RigidBody3D:
			var force_dir = (body.global_position - global_position).normalized()
			body.apply_central_impulse(force_dir * explosion_power)
	debris.emitting = true
	smoke.emitting = true
	fire.emitting = true
	await get_tree().create_timer(2.0).timeout
	queue_free()
