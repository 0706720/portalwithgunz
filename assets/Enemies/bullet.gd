extends Area3D

var speed: float = 25.0
var direction: Vector3 = Vector3.FORWARD
var damage: int = 10

func initialize(dir: Vector3, dmg: int) -> void:
	direction = dir.normalized()
	damage = dmg
	if direction != Vector3.ZERO:
		# Look at the target position in world space
		look_at(global_position + direction, Vector3.UP)

func _physics_process(delta: float) -> void:
	# Only the server should handle movement and collision checks in multiplayer
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return
		
	global_position += direction * speed * delta

func _on_body_entered(body: Node3D) -> void:
	if multiplayer.has_multiplayer_peer() and not multiplayer.is_server():
		return

	# Ignore enemies/CharacterBody3Ds so it doesn't instantly self-destruct on spawn
	if body is CharacterBody3D:
		return

	if body.is_in_group("player") and body.has_method("receive_damage"):
		body.rpc("receive_damage", damage)
		print("[Bullet] Hit player for ", damage, " damage.")
	
	queue_free()

func _on_timer_timeout() -> void:
	queue_free()
