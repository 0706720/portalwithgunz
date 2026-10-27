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

var shooter: Node = null
var has_exploded := false
var spawn_timer := 0.15 # Brief buffer so it clears the player's hand/spawn point safely

func _ready() -> void:
	# Enable contact monitoring so RigidBody3D can detect collisions
	contact_monitor = true
	max_contacts_reported = 4
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
		
	if has_node("Timer"):
		$Timer.timeout.connect(_on_timer_timeout)

func _physics_process(delta: float) -> void:
	if spawn_timer > 0:
		spawn_timer -= delta

# Triggered immediately when the grenade collides with anything in the world
func _on_body_entered(body: Node3D) -> void:
	# connect to up-to-date damage according to singleton reference
	explosion_damage = Global.grenade_damage
	print('global dmg grenade: ' + str(explosion_damage))
	if has_exploded or spawn_timer > 0:
		return
		
	# Explode on contact with environment, enemies, or targets
	explode()

func _on_timer_timeout() -> void:
	# Backup safety timer in case it doesn't hit anything
	explode()

func set_shooter(player: Node) -> void:
	shooter = player

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
		
	# Safely disable collision shapes
	for node in [$CollisionShape3D, get_node_or_null("CollisionShape3D2"), get_node_or_null("CollisionShape3D3")]:
		if node and node is CollisionShape3D:
			node.disabled = true
	
	if explosion_area:
		var overlapping_bodies = explosion_area.get_overlapping_bodies()
		for body in overlapping_bodies:
			if body.is_in_group('Enemy') or body.is_in_group('target'):
				if body.has_method("receive_damage"):
					body.receive_damage.rpc(explosion_damage, shooter)
			if body is RigidBody3D and body != self:
				var force_dir = (body.global_position - global_position).normalized()
				body.apply_central_impulse(force_dir * explosion_power)
				
	if debris: debris.emitting = true
	if smoke: smoke.emitting = true
	if fire: fire.emitting = true
	
	await get_tree().create_timer(2.0).timeout
	queue_free()
