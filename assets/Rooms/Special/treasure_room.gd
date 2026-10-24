extends Node3D

@export var reward_pool: Array[Dictionary] = [
	{"scene": preload("res://assets/Interactables/Rewards/chest_common.tscn"), "weight": 1},
	{"scene": preload("res://assets/Interactables/Rewards/treasure_portal.tscn"), "weight": 100}
]

# Toggle this ON in the Inspector for your Treasure End Room scene!
@export var disable_portal: bool = false

var rng := RandomNumberGenerator.new()
var rewards_spawned := false

func _ready() -> void:
	rng.randomize()
	if multiplayer.is_server():
		# Give a tiny frame delay to ensure the room is fully registered in the scene tree
		await get_tree().process_frame
		spawn_weighted_rewards()

func spawn_weighted_rewards() -> void:
	if rewards_spawned or not multiplayer.is_server():
		return
	rewards_spawned = true

	var spawns_node = get_node_or_null("RewardSpawns")
	if not spawns_node or reward_pool.is_empty(): 
		return
	
	var portal_scene_path = "res://assets/Interactables/Rewards/treasure_portal.tscn"
	var portal_spawned := false
	
	var children = spawns_node.get_children()
	for i in range(children.size()):
		var marker = children[i] as Marker3D
		if marker:
			var chosen_scene = get_weighted_random_reward()
			
			# Ensure portals cannot spawn if disabled for this room type
			if disable_portal and chosen_scene and chosen_scene.resource_path == portal_scene_path:
				chosen_scene = reward_pool[0]["scene"] # Fallback to chest
			
			# Otherwise, ensure only one rare portal spawns per regular room
			elif not disable_portal and chosen_scene and chosen_scene.resource_path == portal_scene_path:
				if portal_spawned:
					chosen_scene = reward_pool[0]["scene"]
				else:
					portal_spawned = true
			
			if chosen_scene:
				# 1. Instantiate locally on the server
				var reward_instance = chosen_scene.instantiate() as Node3D
				add_child(reward_instance)
				reward_instance.global_transform = marker.global_transform
				reward_instance.add_to_group("network_interactables")
				
				# 2. Tell all remote clients to spawn this exact reward safely
				rpc("rpc_spawn_reward_remote", chosen_scene.resource_path, marker.global_transform, i)

@rpc("authority", "call_remote", "reliable")
func rpc_spawn_reward_remote(scene_path: String, tf: Transform3D, index: int) -> void:
	# Executed on clients to mirror the server's spawned reward
	var scene_to_load = load(scene_path) as PackedScene
	if scene_to_load:
		var reward_instance = scene_to_load.instantiate() as Node3D
		add_child(reward_instance)
		reward_instance.global_transform = tf
		reward_instance.add_to_group("network_interactables")

func get_weighted_random_reward() -> PackedScene:
	var total_weight := 0
	for item in reward_pool:
		# Skip portal from weight calculations if disabled
		if disable_portal and item["scene"].resource_path == "res://assets/Interactables/Rewards/treasure_portal.tscn":
			continue
		total_weight += item["weight"]
		
	if total_weight <= 0:
		return reward_pool[0]["scene"]
		
	var roll := rng.randi_range(0, total_weight - 1)
	var cumulative_weight := 0
	
	for item in reward_pool:
		if disable_portal and item["scene"].resource_path == "res://assets/Interactables/Rewards/treasure_portal.tscn":
			continue
		cumulative_weight += item["weight"]
		if roll < cumulative_weight:
			return item["scene"]
			
	return reward_pool[0]["scene"]
