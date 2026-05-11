extends AnimatableBody3D

@export var a := Vector3()
@export var b := Vector3()
@export var time : float = 4
@export var pause : float = 0.7

func _ready():
	move()


func move():
	var move_tween = create_tween()
	move_tween.tween_property(self, "position", b, time)
	move_tween.tween_property(self, "position", a, time)
	await get_tree().create_timer(2 * time).timeout
	move()
