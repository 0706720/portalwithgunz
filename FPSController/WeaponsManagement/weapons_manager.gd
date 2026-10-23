extends Node

# cache actual Node references (use $ or get_node)
@onready var pistol_node    := $"../CameraHolder/Camera3D/Pistol"
@onready var grenade_node   := $"../CameraHolder/Camera3D/GrenadeLauncher"
@onready var grapple_node   := $"../CameraHolder/Camera3D/Grapple Hook"
@onready var portal_node    := $"../CameraHolder/Camera3D/PortalGun"
@onready var sniper_node    := $"../Camera3D/M91"
@onready var shotgun_node   := $"../CameraHolder/Camera3D/Shotgun"

@onready var icon_node = $"../HUD/GrenadeIcon/pistol_test"

# Every joining player starts with exactly one random weapon unlocked.
# All other weapons stay locked.
@export var weapons: Array[Dictionary] = [
	{ "name": "Pistol", "unlocked": false, "icon_path": load("res://assets/images/upgradesSystem/undertaker.webp"), "scale": Vector2(0.17, 0.17)},
	{ "name": "Grenade", "unlocked": false, "icon_path": load("res://assets/images/upgradesSystem/grenade_launcher-Photoroom.png"), "scale": Vector2(1.1, 1.1)},
	{ "name": "GrappleGun", "unlocked": false },
	{ "name": "PortalGun", "unlocked": false },
	{ "name": "Shotgun", "unlocked": false, "icon_path": load("res://assets/images/upgradesSystem/boomstick.png"), "scale": Vector2(0.2, 0.2)}
]

var weapon_nodes: Array = []
var start_weapon_choices: Array = ["Pistol", "Grenade", "Shotgun"]

func _ready() -> void:
	# build the nodes array so indexing matches weapons[]
	weapon_nodes = [pistol_node, grenade_node, grapple_node, portal_node, shotgun_node]
	_assign_random_starting_weapon()
	# optionally include sniper_node where appropriate

func _assign_random_starting_weapon() -> void:
	var chosen_name: String = start_weapon_choices[randi() % start_weapon_choices.size()]

	# lock everything by default, then unlock only the random start weapon
	for i in range(weapons.size()):
		weapons[i]["unlocked"] = weapons[i]["name"] == chosen_name

	# apply the chosen weapon immediately
	for i in range(weapons.size()):
		if weapons[i]["name"] == chosen_name:
			_apply_weapon_local(i)
			return

# Call this locally when the local player changes weapon
func request_weapon_change(weapon_index: int) -> void:
	if not _valid_index(weapon_index):
		return
	if not _unlocked_weapon(weapon_index):
		return

	# change locally for instant feedback
	_apply_weapon_local(weapon_index)

	# broadcast to other peers (exclude self)
	rpc_id(0, "rpc_apply_weapon", weapon_index)

# The RPC handler run on remote peers
@rpc("any_peer", "reliable")
func rpc_apply_weapon(weapon_index: int) -> void:
	if not _valid_index(weapon_index):
		return
	_apply_weapon_local(weapon_index)
	print("RPC applied on peer", get_tree().get_multiplayer().get_unique_id(), "weapon", weapon_index)

func _apply_weapon_local(weapon_index: int) -> void:
	# hide all
	for node in weapon_nodes:
		if node:
			node.visible = false
			node.position = Vector3(-0.5, -0.35, -0.7)

	# show the selected one
	var n = weapon_nodes[weapon_index]
	n.visible = true
	n.position = Vector3(0.5, -0.25, -0.5)

	Global.currentWeapon = weapons[weapon_index]["name"]
	# change UI weapon to the weapon asset defined in the weapons array, then scale appropriately
	icon_node.texture = weapons[weapon_index]["icon_path"]
	icon_node.scale = weapons[weapon_index]["scale"]
	print("Local weapon set to", Global.currentWeapon)

func _valid_index(i: int) -> bool:
	return i >= 0 and i < weapon_nodes.size()

func _unlocked_weapon(i) -> bool:
	if weapons[i]["unlocked"] == true:
		return true
	return false

func unlock_weapon(name: String):
	for entry in weapons:
		if entry["name"] == name:
			entry["unlocked"] = true
