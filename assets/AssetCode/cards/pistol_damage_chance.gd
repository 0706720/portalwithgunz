extends Control
## COMPLETE
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_button_pressed() -> void:
	# fixes the issue of the cards not being attached to player node until runtime.
	# This means we can modify player script variables
	var player = get_tree().get_first_node_in_group("player")
	print("PLAYER IS: " + str(player))
	apply_effect(player)
	
func apply_effect(player) -> void:
	# declared here to avoid variable bloat in player
	var pistol_base = 25
	# EFFECT: +1% chance to roll 4X damage. each card stacks 1. Logic handled in player.
	player.pistol_damage_stacks += 1
	# hide mouse for gameplay
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# this should delete all instances of cards currently on screen, if that isn't happening
	# then ensure all cards belong to group 'Card' in the inspector.
	player.can_look = true
	Global.upgrade_pending -= 1
	if Global.upgrade_pending <= 0:
		Global.signal_popup(false)
	get_tree().call_group("Card", "queue_free")
	
