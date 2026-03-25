extends Node3D

@onready var timer = $Damage_Timer
var target = null
var hazard_damage = 33

func _ready() -> void:
	pass

func _on_body_entered(body: Node3D) -> void:
	print('Collision detected')
	if body.is_in_group("Player"):
		target = body
		target.receive_damage(hazard_damage)
		timer.start()
		print("damage dealt")

func _on_body_exited(body: Node3D) -> void:
	if target == body:
		timer.stop()
		target = null

func _on_timer_timeout() -> void:
	if target != null:
		target.receive_damage(hazard_damage)
