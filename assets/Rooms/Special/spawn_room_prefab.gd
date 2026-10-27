extends Node3D

@export var door_collisions: Array[Node3D] # Accepts StaticBody3D, Area3D, or generic Node3D containers for your spawn doors/walls

@onready var activation_area: Area3D = get_node_or_null("ActivationArea")

var room_opened: bool = false

func _ready() -> void:
	if activation_area:
		if not activation_area.body_entered.is_connected(_on_activation_area_body_entered):
			activation_area.body_entered.connect(_on_activation_area_body_entered)
			
	# Initialize spawn room doors to start CLOSED (blocking enemies from shooting/entering)
	for door in door_collisions:
		if is_instance_valid(door):
			door.show()
			_set_door_collision_state(door, false) # false = enabled (blocking)

func _on_activation_area_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"): 
		return
	
	# If the server detects the body natively, trigger it immediately
	if multiplayer.is_server():
		trigger_room_activation()
		return

	# If a client steps into it locally, tell the server via RPC right away
	if body.name.to_int() == multiplayer.get_unique_id():
		rpc_id(1, "server_request_activate_room")

@rpc("any_peer", "call_remote", "reliable")
func server_request_activate_room() -> void:
	if not multiplayer.is_server(): 
		return
	trigger_room_activation()

func trigger_room_activation() -> void:
	if room_opened: 
		return
	room_opened = true
	
	if activation_area:
		activation_area.set_deferred("monitoring", false)
		
	print("[SpawnRoom] Players have left the safety zone. Opening spawn doors!")
	open_spawn_room()

func open_spawn_room() -> void:
	rpc("client_open_spawn_room")

@rpc("authority", "call_local", "reliable")
func client_open_spawn_room() -> void:
	for door in door_collisions:
		if is_instance_valid(door):
			door.queue_free()

func _set_door_collision_state(parent_node: Node, disabled_state: bool) -> void:
	for child in parent_node.get_children():
		if child is CollisionShape3D:
			child.set_deferred("disabled", disabled_state)
		elif child.get_child_count() > 0:
			_set_door_collision_state(child, disabled_state)
