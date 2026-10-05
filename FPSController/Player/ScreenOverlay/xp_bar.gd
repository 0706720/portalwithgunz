extends ProgressBar

var experience = 0
var level_up_multiplier = 1.5
var level_amount = 50
@onready var progress_node = %xpBar

signal level_up(new_level)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# track outgoing signals from enemies that triggers xp gain
	Global.experience_up.connect(on_xp_gain)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("LevelUp"):
		level_up.emit(1)
	
func on_xp_gain(amount):
	if is_multiplayer_authority():
		experience += amount
		print("NEW XP: " + str(experience))
		if experience >= level_amount:
			level_amount = (level_amount * level_up_multiplier)
			experience = 0
			level_up.emit(1)
		update_progress(experience, level_amount)

func update_progress(exp, max_xp):
	progress_node.value = exp
	progress_node.max_value = max_xp
		
	
