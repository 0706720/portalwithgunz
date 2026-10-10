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
	var upgradeNode = get_tree().get_first_node_in_group("upgrade")
	# This singleton variable will be used to track when jump key is pressed 
	# if this card was previously used
	Global.jump_unlocked = true
	# hide mouse for gameplay
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# unlock jump dependencies
	upgradeNode.unlock_jump()
	# make sure this redundant upgrade doesnt show again
	upgradeNode.clear_unique("unlock_jump")
	# this should delete all instances of cards currently on screen, if that isn't happening
	# then ensure all cards belong to group 'Card' in the inspector.
	get_tree().call_group("Card", "queue_free")
