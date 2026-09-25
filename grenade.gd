extends RigidBody3D

@export var explosion_power: float = 10.0
@export var explosion_damage: float = 50.0
@onready var explosion_area: Area3D = $Area3D
@onready var debris: GPUParticles3D = $Grenade_explosion/Debris2
@onready var smoke: GPUParticles3D = $Grenade_explosion/Smoke2
@onready var fire: GPUParticles3D = $Grenade_explosion/Fire2
@onready var mesh_instance = $MeshInstance3D 

# Called when the node enters the scene tree for the fssirst time.
func _ready() -> void:
	$Timer.timeout.connect(_on_timer_timeout)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_timer_timeout() -> void:
	explode()

func explode() -> void:
	freeze = true
	if mesh_instance:
		mesh_instance.visible = false
	$CollisionShape3D.disabled = true
	var overlapping_bodies = explosion_area.get_overlapping_bodies()
	for body in overlapping_bodies:
		if body is RigidBody3D:
			var force_dir = (body.global_position - global_position).normalized()
			body.apply_central_impulse(force_dir * explosion_power)
	debris.emitting = true
	smoke.emitting = true
	fire.emitting = true
	await get_tree().create_timer(2.0).timeout
	queue_free()
