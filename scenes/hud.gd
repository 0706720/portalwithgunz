extends Control

@onready var player = get_parent()
@onready var health_bar = $healthBar
@onready var health_disp = $healthVar
@onready var health_max = $healthMax

func _ready():
	player.health_changed.connect(_on_player_health_changed)

func _on_player_health_changed(health):
	health_bar.value = health
	health_disp.text = str(health)
	var view_max = int(health_bar.max_value)
	health_max.text = str(view_max)



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
