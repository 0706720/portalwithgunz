extends Node3D

@export var reward_pool: Array[Dictionary] = [
	{"scene": preload("res://assets/Interactables/Rewards/chest_common.tscn"), "weight": 50},
	{"scene": preload("res://assets/Interactables/Rewards/upgrade_station.tscn"), "weight": 35},
	{"scene": preload("res://assets/Interactables/Rewards/treasure_portal.tscn"), "weight": 15}
]

var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	if multiplayer.is_server():
		spawn_weighted_rewards()


func spawn_weighted_rewards() -> void:
	var spawns_node = get_node_or_null("RewardSpawns")
	if not spawns_node or reward_pool.is_empty(): return
	
	var portal_scene_path = "res://assets/Interactables/Rewards/treasure_portal.tscn"
	var portal_spawned := false
	
	for i in range(spawns_node.get_child_count()):
		var marker = spawns_node.get_child(i) as Marker3D
		if marker:
			var chosen_scene = get_weighted_random_reward()
			
			# Ensure only one rare portal spawns per treasure room
			if chosen_scene and chosen_scene.resource_path == portal_scene_path:
				if portal_spawned:
					chosen_scene = reward_pool[0]["scene"]
				else:
					portal_spawned = true
			
			if chosen_scene:
				# 1. Instantiate locally on the server
				var reward_instance = chosen_scene.instantiate() as Node3D
				add_child(reward_instance)
				reward_instance.global_transform = marker.global_transform
				
				# 2. Tell all remote clients to spawn this exact reward
				rpc("rpc_spawn_reward_remote", name, chosen_scene.resource_path, marker.global_transform, i)


@rpc("authority", "call_remote", "reliable")
func rpc_spawn_reward_remote(room_name: String, scene_path: String, tf: Transform3D, index: int) -> void:
	# Executed on clients to mirror the server's spawned reward
	var scene_to_load = load(scene_path) as PackedScene
	if scene_to_load:
		var reward_instance = scene_to_load.instantiate() as Node3D
		add_child(reward_instance)
		reward_instance.global_transform = tf


func get_weighted_random_reward() -> PackedScene:
	var total_weight := 0
	for item in reward_pool:
		total_weight += item["weight"]
		
	var roll := rng.randi_range(0, total_weight - 1)
	var cumulative_weight := 0
	
	for item in reward_pool:
		cumulative_weight += item["weight"]
		if roll < cumulative_weight:
			return item["scene"]
			
	return reward_pool[0]["scene"]
