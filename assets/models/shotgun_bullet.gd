extends RigidBody3D

@export var Bullet_Speed = 5.0
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	move_and_collide(-transform.basis.z * delta * Bullet_Speed)
	pass

func on_hit_area_entered(body):
	if body.is_in_group("Object"):
		body.queue_free()
		queue_free()
	pass
