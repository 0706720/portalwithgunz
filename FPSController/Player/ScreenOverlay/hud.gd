extends Control

@onready var player = get_parent()
@onready var health_bar = $healthBar
@onready var health_disp = $healthVar
@onready var health_max = $healthMax

func _ready() -> void:
	# Wait a frame so multiplayer authority assignment completes across the network
	await get_tree().process_frame
	
	if not player:
		return

	# Connect to the player's health_changed signal
	if player.has_signal("health_changed") and not player.health_changed.is_connected(_on_player_health_changed):
		player.health_changed.connect(_on_player_health_changed)

	# Update visibility and populate initial values
	update_hud_visibility()

func update_hud_visibility() -> void:
	if not player:
		return

	# Only display the HUD if this local screen controls this player instance
	if player.is_multiplayer_authority():
		show()
		# Use player's current health and max_health if available
		var current_hp = player.get("health") if "health" in player else player.get("current_health")
		var max_hp = player.get("max_health") if "max_health" in player else 100
		
		if current_hp != null:
			_on_player_health_changed(current_hp, max_hp)
	else:
		hide()

func _on_player_health_changed(health: int, maxhealth: int) -> void:
	if not player:
		return

	if player.is_multiplayer_authority():
		show()
		health_bar.max_value = maxhealth
		health_bar.value = health
		health_disp.text = str(health)
		health_max.text = str(maxhealth)
	else:
		hide()
