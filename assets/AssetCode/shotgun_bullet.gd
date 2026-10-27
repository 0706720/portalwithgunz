extends Area3D

@export var Bullet_Speed: float = 120.0
@export var damage: int = 15

var shooter: Node3D = null # Assigned by the shotgun when spawned

func _ready() -> void:
	await get_tree().create_timer(3.0).timeout
	queue_free()

func _process(delta: float) -> void:
	global_translate(global_transform.basis.z * Bullet_Speed * delta)

func _on_body_entered(body: Node3D) -> void:
	# connect to up-to-date damage according to singleton reference
	damage = Global.shotgun_damage
	print('global dmg shotty: ' + str(damage))
	# Ignore the specific player who fired this bullet
	if body == shooter or (body is CharacterBody3D and body.is_in_group("player")):
		return

	# Check if body or parent has receive_damage
	var target = body
	if not target.has_method("receive_damage") and target.get_parent() and target.get_parent().has_method("receive_damage"):
		target = target.get_parent()

	if target.has_method("receive_damage"):
		print("[Bullet] Dealing ", damage, " damage to: ", target.name)
		target.receive_damage.rpc(damage, shooter)
		queue_free()
	else:
		# Hit a wall, floor, or non-damageable object
		queue_free()
