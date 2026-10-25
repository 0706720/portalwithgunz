extends Node3D
@onready var node = $"."

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_area_3d_body_entered(body: Node3D) -> void:
	if multiplayer.is_server() and body.is_in_group("player"):
		rpc("apply_upgrade_all_clients", 3)

@rpc("authority", "call_local", "reliable")
func apply_upgrade_all_clients(value: int):
	Global.upgrade_pending = max(0, Global.upgrade_pending + value)
	Global.signal_popup(true)
	
	if is_inside_tree():
		node.queue_free()
		
	
