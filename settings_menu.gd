extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("Settings menu"):
		get_tree().change_scene_to_file("res://settings_menu.tscn")


func _on_return_to_game_pressed() -> void:
	get_tree().change_scene_to_file("res://Map.tscn")




func _on_advanced_settings_pressed() -> void:
	if $"Advanced menu".visible == false:
		$"Advanced menu".visible = true 
	else:
		$"Advanced menu".visible = false


func _on_quit_pressed() -> void:
	get_tree().quit()
