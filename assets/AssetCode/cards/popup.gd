extends Node2D

@onready var node = %Popup

func _ready() -> void:
	Global.signal_message.connect(alert_toggle)

func apply_all_clients(status: bool) -> void:
	if multiplayer.is_server():
		rpc("alert_toggle", status)

@rpc("any_peer", "call_local", "reliable")
func alert_toggle(status: bool) -> void:
	node.visible = status
