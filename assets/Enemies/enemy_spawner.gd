# EnemySpawner.gd
extends Node3D

@export var available_enemies: Array[EnemySpawnData] = []
@export var spawn_markers_node: Node3D # Parent node containing Marker3D nodes for spawn spots

func spawn_room_enemies(room_difficulty: float) -> void:
	if available_enemies.is_empty() or not spawn_markers_node:
		return

	# 1. Calculate total budget for this room (e.g., base 10 points scaled by difficulty)
	var total_budget := int(round(10.0 * max(0.5, room_difficulty)))
	var remaining_budget := total_budget
	
	# 2. Get available spawn points and shuffle them
	var spawn_points := spawn_markers_node.get_children()
	spawn_points.shuffle()
	var spawn_index := 0

	print_rich("[color=yellow]Spawning enemies. Room Budget: %d points[/color]" % total_budget)

	# 3. Point-buy loop
	while remaining_budget > 0 and spawn_index < spawn_points.size():
		# Filter enemies that fit within the remaining budget AND don't exceed 50% of the total budget per unit
		var max_single_unit_cost = int(ceil(total_budget * 0.5))
		
		var valid_enemies = available_enemies.filter(func(e): 
			return e.point_cost <= remaining_budget and e.point_cost <= max_single_unit_cost
		)

		if valid_enemies.is_empty():
			break

		# Sort/weight to favor mid-high tier options (e.g., costs closer to the 40-50% threshold)
		valid_enemies.sort_custom(func(a, b):
			# Prefer higher costs up to the threshold
			return a.point_cost > b.point_cost
		)

		# Pick an enemy using a biased random selection or top-weighted choice
		var chosen_enemy: EnemySpawnData = select_biased_enemy(valid_enemies, total_budget)
		if not chosen_enemy:
			break

		# Instantiate the enemy at the marker location
		var marker := spawn_points[spawn_index] as Marker3D
		var enemy_instance = chosen_enemy.enemy_scene.instantiate() as Node3D
		
		get_tree().current_scene.add_child(enemy_instance)
		enemy_instance.global_transform = marker.global_transform

		remaining_budget -= chosen_enemy.point_cost
		spawn_index += 1

func select_biased_enemy(valid_list: Array[EnemySpawnData], total_budget: int) -> EnemySpawnData:
	# Favors the middle-upper tier range (e.g., 3, 4, 5 cost out of 10)
	var target_sweet_spot := total_budget * 0.4
	
	# Sort or weight based on proximity to the sweet spot
	valid_list.sort_custom(func(a, b):
		var diff_a = abs(a.point_cost - target_sweet_spot)
		var diff_b = abs(b.point_cost - target_sweet_spot)
		return diff_a < diff_b
	)

	# Add a little randomness by picking from the top 3 best matches if available
	var pick_range = min(3, valid_list.size())
	return valid_list[randi() % pick_range]
