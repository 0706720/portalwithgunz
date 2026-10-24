class_name Bullet
extends Area3D

@export var speed := 25.0
var direction := Vector3.FORWARD
var damage := 10

func initialize(dir: Vector3, dmg: int) -> void:
	direction = dir.normalized()
	damage = dmg
	
	if direction != Vector3.ZERO:
		look_at(global_position + direction, Vector3.UP)

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func _on_body_entered(body: Node3D) -> void:
	# Only the server handles damage/cleanup logic to avoid duplicate calls
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		queue_free()
		return

	# IGNORE the enemy that fired it so it doesn't self-destruct on spawn
	# (Assumes your enemies extend 'Enemy' or are in an 'enemy' group)
	if body is Enemy or body.is_in_group("enemy"):
		return

	# If it hits the player, deal damage
	if body.has_method("take_damage"):
		body.take_damage(damage)
		print("[Bullet] Successfully dealt ", damage, " damage to ", body.name)
	
	# Destroy the bullet upon hitting the player or a wall
	queue_free()
