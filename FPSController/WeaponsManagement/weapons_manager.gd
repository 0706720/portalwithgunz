extends Node

# cache actual Node references (use $ or get_node)
@onready var pistol_node    := $"../CameraHolder/Camera3D/Pistol"
@onready var shotgun_node   := $"../CameraHolder/Camera3D/Propulsion_shotgun"
@onready var grapple_node   := $"../CameraHolder/Camera3D/Grapple Hook"
@onready var portal_node    := $"../CameraHolder/Camera3D/PortalGun"
@onready var sniper_node    := $"../Camera3D/M91"

var weapons = ["Pistol", "Shotgun", "GrappleGun", "PortalGun"]
var weapon_nodes: Array = []

func _ready() -> void:
	# build the nodes array so indexing matches weapons[]
	weapon_nodes = [pistol_node, shotgun_node, grapple_node, portal_node]
	# optionally include sniper_node where appropriate
	print("weapons:", weapons)

# Call this locally when the local player changes weapon
func request_weapon_change(weapon_index: int) -> void:
	if not _valid_index(weapon_index):
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
	Global.currentWeapon = weapons[weapon_index]
	print("Local weapon set to", Global.currentWeapon)

func _valid_index(i: int) -> bool:
	return i >= 0 and i < weapon_nodes.size()

#extends Node
#
## .. is simply a reference to the parent node.
#@onready var pistolNode = ^"../CameraHolder/Camera3D/Pistol"
#@onready var shotgunNode = ^"../CameraHolder/Camera3D/Propulsion_shotgun"
#@onready var grappleNode = ^"../CameraHolder/Camera3D/Grapple Hook"
#@onready var portalNode = ^"../CameraHolder/Camera3D/PortalGun"
## non-initial weapon (sniper instance)
#@onready var sniperNode = ^"../Camera3D/M91"
#
#var weapons = ["Pistol", "Shotgun", "GrappleGun", "PortalGun"]
#
#var paths = [
	#"res://scenes/models/Pistol.glb", 
	#"res://assets/images/Weapons/Shotgunz/spas12.FBX",
	#"res://assets/images/Weapons/Vacuum Cleanerz/vacuum3.fbx",
	#"res://assets/images/Weapons/Sniperz/M91.fbx",
	#"res://assets/images/Weapons/portalGunz/portalgun2.obj"
	#]
#
#var nodepaths = ["%Pistol", "%Propulsion_shotgun", "%Grapple Hook", "%PortalGun"]
#
## Called when the node enters the scene tree for the first time.
#func _ready() -> void:
	#print(weapons[0])
#
## this should automate new weapons being added, using unique node name and name of weapon.
#func import_weapon(weaponname: String, nodepath: String):
	#weapons.append(weaponname)
	#nodepaths.append(nodepath)
	##var scene = load("")
	#print('new weapons array: ' + str(weapons) + ' new nodepaths array: ' + str(nodepaths))
	#
#@rpc("authority", "call_local", "reliable")
#func print(weapon_index):
	## below line is needed due to the lack of a 'try'syntax in godot.
	#if weapon_index >= 0 and weapon_index < nodepaths.size():
		#var weaponInstance
		## for all weapons, reset location to the left of the player and make invisible
		#for i in nodepaths:
			#weaponInstance = get_node(i)
			#weaponInstance.visible = false
			#weaponInstance.position = Vector3(-0.5, -0.35, -0.7)
		#
		#var nodeReference = nodepaths[weapon_index]
		#weaponInstance = get_node(nodeReference)
		## make desired weapon visible and move to right of camera
		#weaponInstance.visible = true
		#weaponInstance.position = Vector3(0.5, -0.25, -0.5)
		## update global weapon name for player script firing checks (you shouldn't be able to fire a weapon you're not using)
		#Global.currentWeapon = weapons[weapon_index]
		#print(Global.currentWeapon)
	#else:
		## if weapon not in arrays is requested using number keys
		#print('weapon index fetch unsuccessful')
		#
#func _process(delta: float) -> void:
	#pass
