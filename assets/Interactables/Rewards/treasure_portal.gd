extends Node3D

@onready var portal_area: Area3D = $Portal/PortalArea

func _ready() -> void:
	if portal_area:
		if not portal_area.body_entered.is_connected(_on_body_entered):
			portal_area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	# Only the server should handle portal logic to prevent duplicate triggers
	if not multiplayer.is_server():
		return
		
	if body.is_in_group("player"):
		print("[TreasurePortal] Player entered dynamic treasure portal!")
		
		if Global and "current_generator" in Global and Global.current_generator:
			portal_area.set_deferred("monitoring", false)
			Global.current_generator.trigger_treasure_branch(body)
		else:
			push_warning("[TreasurePortal] Global.current_generator not found!")
