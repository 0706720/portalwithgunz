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
	var shotgun_base = 15
	var grenade_base = 50
	# This is a global increase, so just adjust everything. Will be relevant if
	# player is eventually allowed multiple weapons.
	pistol_modify(player, pistol_base)
	shotgun_modify(player, shotgun_base)
	grenade_modify(player, grenade_base)
	# hide mouse for gameplay
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# this should delete all instances of cards currently on screen, if that isn't happening
	# then ensure all cards belong to group 'Card' in the inspector.
	player.can_look = true
	Global.upgrade_pending -= 1
	if Global.upgrade_pending <= 0:
		Global.signal_popup(false)
	get_tree().call_group("Card", "queue_free")
	
	
func pistol_modify(player, pistol_base):
	# +10% pistol base dmg
	var current_pistol_damage = player.pistol_damage
	player.pistol_damage = current_pistol_damage + (pistol_base / 10)
	print("PISTOL: " + str(player.pistol_damage))
	
func shotgun_modify(player, shotgun_base):
	var shotgun_current_damage = Global.shotgun_damage
	Global.shotgun_damage = shotgun_current_damage + (shotgun_base / 10)
	
func grenade_modify(player, grenade_base):
	var grenade_current_damage = Global.grenade_damage
	Global.grenade_damage = grenade_current_damage + (grenade_base / 10)
