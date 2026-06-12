extends Node3D

@onready var timer = $Damage_Timer
# initialize target, this will track what is caught in hazard's collision shape
var target = null
# damage player will take upon hazard tick (every second)
var hazard_damage = 33

func _ready() -> void:
	pass

func _on_body_entered(body: Node3D) -> void:
	#print('Collision detected')
	if body.is_in_group("Player"):
		target = body
		# call damage function on player script with defined hazard damage
		target.receive_damage(hazard_damage)
		# begin the 1 second timer, for damage ticks every second
		timer.start()
		print("damage dealt")

func _on_body_exited(body: Node3D) -> void:
	# if target is player
	if target == body:
		# stop timer, and therefore stop damage ticks when collision shape is exited
		timer.stop()
		target = null

func _on_timer_timeout() -> void:
	# if something is inside collision shape
	if target != null:
		# call recieve damage function on the player every second
		target.receive_damage(hazard_damage)
