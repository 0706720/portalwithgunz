extends Node

# Target difficulty range (0.0 = Peaceful, 1.0 = Max Intensity)
var dynamic_difficulty := 0.2
var player_stress := 0.0

# Tracks pacing states: BUILDUP, PEAK, RELAX
enum PacingState { BUILDUP, PEAK, RELAX }
var current_pacing := PacingState.BUILDUP

func update_director_state(player_health_pct: float, time_in_combat: float) -> void:
	# Calculate stress based on player state
	if player_health_pct < 0.3:
		player_stress += 0.15
	
	player_stress += time_in_combat * 0.05
	
	# Adjust difficulty dynamically
	if player_stress > 0.8:
		current_pacing = PacingState.RELAX
		dynamic_difficulty = max(0.1, dynamic_difficulty - 0.2)
	elif player_stress < 0.3:
		current_pacing = PacingState.BUILDUP
		dynamic_difficulty = min(1.0, dynamic_difficulty + 0.1)
