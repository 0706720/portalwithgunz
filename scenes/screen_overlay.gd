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

func _process(_delta : float) -> void:
	display_current_FPS()
	
	display_properties()
	
func display_properties() -> void:
	current_state_label_text.set_text(str(play_char.state_machine.curr_state_name))
	desired_move_speed_label_text.set_text(str(round_to_3_decimals(play_char.desired_move_speed)))
	is_on_floor_label_text.set_text(str(play_char.is_on_floor()))
	velocity_label_text.set_text(str(round_to_3_decimals(play_char.velocity.length())))
	Air_speed_label_text.set_text(str(round_to_3_decimals(play_char.move_speed)))
	#Portal_two_Label_text.set_txt(str(round_to_3_decimals()))
	#Portal_two_Label_text.set_txt(str(round_to_3_decimals()))

func display_current_FPS() -> void:
	frames_per_second_label_text.set_text(str(Engine.get_frames_per_second()))
	
func round_to_3_decimals(value: float) -> float:
	return round(value * 1000.0) / 1000.0
