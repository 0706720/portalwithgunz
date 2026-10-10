extends ProgressBar

var experience = 0
# how much harder it is to level up after each level completion
var level_up_multiplier = 1.5
# initial xp requirement
var level_amount = 50
@onready var progress_node = %xpBar

# main recipient of this signal is the upgrades_system.gd to display cards
signal level_up(new_level)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# track outgoing signals from enemies that triggers xp gain
	Global.experience_up.connect(on_xp_gain)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# developer tool that will not remain permanently
	if Input.is_action_just_pressed("LevelUp"):
		level_up.emit(1)
	
func on_xp_gain(amount):
	if is_multiplayer_authority():
		experience += amount
		print("NEW XP: " + str(experience))
		# logic for xp reaching requirement
		if experience >= level_amount:
			level_amount = (level_amount * level_up_multiplier)
			experience = 0
			level_up.emit(1)
		update_progress(experience, level_amount)

func update_progress(exp, max_xp):
	# change experience and max experience on UI reguardless if level up occured
	progress_node.value = exp
	progress_node.max_value = max_xp
	
	
