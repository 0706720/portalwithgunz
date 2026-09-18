extends RigidBody3D

@export var Bullet_Speed = 20.0
@export var max_bullets: int = 10
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	move_and_collide(-transform.basis.z * delta * Bullet_Speed)
	var bullets = get_tree().get_nodes_in_group("Bullet")
	if bullets.size() > max_bullets:
		bullets[0].queue_free()

func on_hit_area_entered(body):
	if body.is_in_group("Object"):
		body.queue_free()
		queue_free()
	pass
