extends CanvasLayer

class_name HUD

#player character reference variable
@onready var play_char : PlayerCharacter = $".."

#label references variables
@onready var desired_move_speed_label_text: Label = %DesiredMoveSpeedLabelText
@onready var is_on_floor_label_text: Label = %IsOnFloorLableText
@onready var frames_per_second_label_text: Label = %FramesPerSecondLabelText
@onready var current_state_label_text: Label = %CurrentStateLabelText
@onready var velocity_label_text: Label = %VelocityLabelText
@onready var Air_speed_label_text: Label = %AirSpeedLabelText
@onready var Portal_one_Label_text: Label = %PortalOneLabelText
@onready var Portal_two_Label_text: Label = %PortalTwoLabelText
@onready var Points_label_text: Label = %PointsLabelText

# Level & Status label reference
@onready var current_level_label_text: Label = %currentLevelLabelText

func _ready() -> void:
	# Give the engine a couple of frames to ensure all nodes and singletons are fully loaded
	await get_tree().create_timer(0.1).timeout
	
	# Keep trying to find the generator until it's available
	var procedural_gen = Global.get("current_generator")
	
	# Fallback to finding it via group if Global hasn't caught it yet
	if not procedural_gen:
		procedural_gen = get_tree().get_first_node_in_group("generator")
	
	if procedural_gen and is_instance_valid(procedural_gen):
		var current_loop = procedural_gen.dungeon_loop
		var is_treasure = procedural_gen.is_treasure_run
		
		if current_level_label_text:
			var status_text = "Treasure Branch" if is_treasure else "Standard Dungeon"
			current_level_label_text.text = "Loop: %d | Status: %s" % [current_loop, status_text]
	else:
		# Ultimate fallback so it never stays blank on level 1
		if current_level_label_text:
			current_level_label_text.text = "Loop: 1 | Status: Standard Dungeon"

func _process(_delta : float) -> void:
	display_current_FPS()
	display_properties()
	
func display_properties() -> void:
	if is_multiplayer_authority():
		current_state_label_text.set_text(str(play_char.state_machine.current_state.state_name))
		desired_move_speed_label_text.set_text(str(round_to_3_decimals(play_char.desired_move_speed)))
		is_on_floor_label_text.set_text(str(play_char.is_on_floor()))
		velocity_label_text.set_text(str(round_to_3_decimals(play_char.velocity.length())))
		Air_speed_label_text.set_text(str(round_to_3_decimals(play_char.move_speed)))
		Points_label_text.set_text(str(Global.current_score))
	else:
		hide()

func display_current_FPS() -> void:
	frames_per_second_label_text.set_text(str(Engine.get_frames_per_second()))
	
func round_to_3_decimals(value: float) -> float:
	return round(value * 1000.0) / 1000.0
