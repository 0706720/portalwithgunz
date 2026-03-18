extends Area3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var bodies = get_overlapping_bodies()
	print(bodies)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_body_entered(body: Node3D) -> void:
	print('Collision detected Target')
	# replace with groupname of bullet in future. Player is a placeholder.
	if body.is_in_group("Player"):
		queue_free()
