class_name Bullet
extends Area3D

@export var speed := 25.0
var direction := Vector3.FORWARD
var damage := 10

func initialize(dir: Vector3, dmg: int) -> void:
	direction = dir.normalized()
	damage = dmg
	
	# Instantly face the direction it's traveling so the mesh points straight at the target
	if direction != Vector3.ZERO:
		look_at(global_position + direction, Vector3.UP)

func _physics_process(delta: float) -> void:
	# REMOVE any "if not multiplayer.is_server(): return" here! 
	# Clients need to update the bullet's position visually too since you used call_local.
	
	global_position += direction * speed * delta

func _on_body_entered(body: Node3D) -> void:
	# Only the server should handle damage logic to avoid duplicate hits
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		queue_free()
		return

	# Ignore the enemy that fired it so it doesn't self-destruct on spawn
	if body is CharacterBody3D and not body.is_in_group("player"):
		return

	if body.is_in_group("player") and body.has_method("receive_damage"):
		body.rpc("receive_damage", damage)
	
	queue_free()
