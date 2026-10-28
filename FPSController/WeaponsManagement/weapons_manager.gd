class_name WeaponsManager
extends Node
# variable sent to upgrades system to allocate correct cards array.
signal weapon_name(weaponname)

@onready var pistol_node     := $"../CameraHolder/Camera3D/Pistol"
@onready var grenade_node    := $"../CameraHolder/Camera3D/GrenadeLauncher"
@onready var shotgun_node    := $"../CameraHolder/Camera3D/Shotgun"
@onready var grapple_node    := $"../CameraHolder/Camera3D/Grapple Hook"

@onready var icon_node = $"../HUD/GrenadeIcon/pistol_test"

@export var weapons: Array[Dictionary] = [
	{ "name": "Pistol", "unlocked": false, "icon_path": load("res://assets/images/upgradesSystem/pistol_2d.png"), "scale": Vector2(0.23, 0.23), "pos": Vector2(478, 234)},
	{ "name": "Grenade", "unlocked": false, "icon_path": load("res://assets/images/upgradesSystem/grenade_2d.png"), "scale": Vector2(0.27, 0.27), "pos": Vector2(485, 254)},
	{ "name": "Shotgun", "unlocked": false, "icon_path": load("res://assets/images/upgradesSystem/shotgun_2d.png"), "scale": Vector2(0.25, 0.25), "pos": Vector2(485, 254)},
	{ "name": "GrappleGun", "unlocked": false, "icon_path": load("res://assets/images/upgradesSystem/grapple_2d.png"), "scale": Vector2(0.27, 0.27), "pos": Vector2(478, 231)}
]

var weapon_nodes: Array = []
var start_weapon_choices: Array = ["Pistol", "Grenade", "Shotgun"]
var current_weapon_name: String = ""
var assigned_index: int = -1
var intialised = false

func _ready() -> void:
	weapon_nodes = [pistol_node, grenade_node, shotgun_node, grapple_node]
	
	# Hide all weapon meshes initially
	for node in weapon_nodes:
		if node:
			node.visible = false

	# Wait for node tree to finish setting up
	await get_tree().process_frame

	# Only the server handles assigning and rolling the weapon for this player instance
	if multiplayer.is_server():
		var chosen_name: String = start_weapon_choices[randi() % start_weapon_choices.size()]
		assigned_index = _get_index_by_name(chosen_name)
		sync_assigned_weapon.rpc(assigned_index)
	else:
		# If a client joins late and the node already exists, ask the server for the assigned weapon
		request_weapon_sync.rpc_id(1, get_parent().name)

@rpc("any_peer", "reliable")
func request_weapon_sync(node_name: String) -> void:
	if multiplayer.is_server() and assigned_index != -1:
		var sender_id = multiplayer.get_remote_sender_id()
		sync_assigned_weapon.rpc_id(sender_id, assigned_index)

@rpc("any_peer", "reliable", "call_local")
func sync_assigned_weapon(weapon_index: int) -> void:
	assigned_index = weapon_index

	# IMPORTANT: do not wipe all other unlock states.
	# Only ensure the selected weapon is unlocked.
	# Other weapons keep their current lock/unlock state.
	for i in range(weapons.size()):
		if i == weapon_index:
			weapons[i]["unlocked"] = true
		# leave all other weapons alone
	
	# this will be sent to upgrades system, as a string of the weapon. Only upon join.
	if !intialised:
		weapon_name.emit(start_weapon_choices[assigned_index])
	intialised = true
	_apply_weapon_local(weapon_index)

func request_weapon_change(weapon_index: int) -> void:
	if not _valid_index(weapon_index):
		return

	# Standard gate: only allow switch if the weapon is unlocked
	if not weapons[weapon_index].get("unlocked", false):
		return

	rpc("sync_assigned_weapon", weapon_index)

func _apply_weapon_local(weapon_index: int) -> void:
	for node in weapon_nodes:
		if node:
			node.visible = false
			node.position = Vector3(-0.5, -0.35, -0.7)

	var n = weapon_nodes[weapon_index]
	if n:
		n.visible = true
		n.position = Vector3(0.5, -0.25, -0.5)

	current_weapon_name = weapons[weapon_index]["name"]
	Global.currentWeapon = current_weapon_name

	# Only update HUD for the local player's own screen
	if get_parent().is_multiplayer_authority() and weapons[weapon_index]["icon_path"] and icon_node:
		icon_node.texture = weapons[weapon_index]["icon_path"]
		icon_node.scale = weapons[weapon_index]["scale"]
		icon_node.position = weapons[weapon_index]["pos"]
		
	print("Weapon active for node ", get_parent().name, " : ", current_weapon_name)
	
func _get_index_by_name(w_name: String) -> int:
	for i in range(weapons.size()):
		if weapons[i]["name"] == w_name:
			return i
	return 0

func _valid_index(i: int) -> bool:
	return i >= 0 and i < weapon_nodes.size()

func unlock_weapon(w_name: String) -> void:
	for entry in weapons:
		if entry["name"] == w_name:
			entry["unlocked"] = true
