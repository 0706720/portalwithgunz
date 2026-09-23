extends Area3D

@export var Bullet_Speed = 120
@export var max_bullets: int = 7
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	global_translate(-global_transform.basis.z * Bullet_Speed * delta)

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("Object"):
		queue_free()
