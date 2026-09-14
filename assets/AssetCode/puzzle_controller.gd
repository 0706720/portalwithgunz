extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _update_puzzle_complexity(modifiers):
	complexity_level = int(lerp(1, max_complexity, modifiers.puzzle_complexity))
	rebuild_puzzle()
