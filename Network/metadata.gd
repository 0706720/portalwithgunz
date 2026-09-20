extends Node

## Difficulty score between 0.0 (e.g., safe room) and 1.0 (e.g., intense boss arena)
@export_range(0.0, 1.0) var difficulty_weight: float = 0.0

## Tags describing room functionality (e.g., ["corridor", "straight", "arena", "safe", "puzzle"])
@export var room_type: Array[String] = []

@export var enemy_budget  :float 


## Helper method to check if this room satisfies a specific tag
func has_type(type_name: String) -> bool:
	return type_name.to_lower() in room_type.map(func(t): return t.to_lower())
