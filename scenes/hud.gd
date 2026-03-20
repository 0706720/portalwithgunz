extends Control

@onready var player = get_parent()
@onready var health_bar = $healthBar

func _ready():
	player.health_changed.connect(_on_player_health_changed)

func _on_player_health_changed(health):
	health_bar.value = health



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
