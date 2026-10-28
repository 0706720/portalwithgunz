extends ProgressBar

var experience = 0
var level_amount = 50
var level_up_multiplier = 1.2

@onready var progress_node = %xpBar

# main recipient of this signal is the upgrades_system.gd to display cards
signal level_up(new_level)

func _ready() -> void:
	# Only the server should track global game XP/leveling logic to keep clients in sync
	if multiplayer.is_server():
		Global.experience_up.connect(on_xp_gain)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("LevelUp") and Global.upgrade_pending >= 1 and !selecting():
		level_up.emit(1)
	
func on_xp_gain(amount):
	# Restrict processing entirely to the multiplayer server authority
	if not multiplayer.is_server():
		return

	# Check if we are currently inside a treasure branch/run for bonus XP scaling
	# (Assuming your procedural generator or Global tracks 'is_treasure_run')
	var procedural_gen = get_tree().get_first_node_in_group("generator")
	if procedural_gen and "is_treasure_run" in procedural_gen and procedural_gen.is_treasure_run:
		# Apply a multiplier for treasure branches (e.g., 2.0x XP)
		amount *= 5.0 

	if Global.xp_threshold_card >= 1.0:
		var am = float(amount)
		var extra_amount = am / 10 * Global.xp_threshold_card
		amount = am + extra_amount
		print("extra exp is: " + str(extra_amount) + " original exp: " + str(am) + " final xp: " + str(amount))
		
	experience += amount

	# Logic for xp reaching requirement
	while experience > 0:
		if experience >= level_amount:
			experience -= level_amount
			create_new_level()
			rpc("apply_upgrade_all_clients")
		else:
			break
		
	# Synchronize progress across all clients
	rpc("rpc_sync_xp_progress", experience, level_amount)

@rpc("any_peer", "call_local", "reliable")
func rpc_sync_xp_progress(exp: float, max_xp: float) -> void:
	update_progress(exp, max_xp)

func update_progress(exp, max_xp):
	progress_node.value = exp
	progress_node.max_value = max_xp
	
func create_new_level():
	level_amount = (level_amount * level_up_multiplier)

@rpc("any_peer", "call_local", "reliable")
func apply_upgrade_all_clients():
	Global.upgrade_pending += 1
	Global.signal_popup(true)
	
func selecting():
	# if no cards are on screen, the func will give true and the if statement will fail.
	# this avoids another global variable.
	if get_tree().get_nodes_in_group("Card").size() >= 1:
		return true
	else:
		return false
