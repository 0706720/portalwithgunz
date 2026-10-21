extends Node2D
var status = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.signal_message.connect(alert_toggle)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func alert_toggle():
	status = !status
	var node = %Popup
	node.visible = status
