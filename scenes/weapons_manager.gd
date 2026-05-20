extends Node

# .. is simply a reference to the parent node.
@onready var pistolNode = ^"../Camera3D/Pistol"
@onready var shotgunNode = ^"../Camera3D/Propulsion_shotgun"
@onready var grappleNode = ^"../Camera3D/Grapple Hook"
# non-initial weapon (sniper instance)
@onready var sniperNode = ^"../Camera3D/M91"

var weapons = ["Pistol", "Shotgun", "GrappleGun"]

var paths = [
	"res://scenes/models/Pistol.glb", 
	"res://assets/images/Weapons/Shotgunz/spas12.FBX",
	"res://assets/images/Weapons/Vacuum Cleanerz/vacuum3.fbx",
	"res://assets/images/Weapons/Sniperz/M91.fbx"
	]

var nodepaths = [^"../Camera3D/Pistol", ^"../Camera3D/Propulsion_shotgun", ^"../Camera3D/Grapple Hook"]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print(weapons[0])

# this should automate new weapons being added.
func import_weapon(weaponname: String, nodepath: String):
	weapons.append(weaponname)
	nodepaths.append(nodepath)
	#var scene = load("")
	print('new weapons array: ' + str(weapons) + ' new nodepaths array: ' + str(nodepaths))
	
func print(weapon_index):
	# below line is needed due to the lack of a 'try'syntax in godot.
	if weapon_index >= 0 and weapon_index < nodepaths.size():
		var weaponInstance
		# for all weapons, reset location to the left of the player and make invisible
		for i in nodepaths:
			weaponInstance = get_node(i)
			weaponInstance.visible = false
			weaponInstance.position = Vector3(-0.5, -0.35, -0.7)
		
		var nodeReference = nodepaths[weapon_index]
		weaponInstance = get_node(nodeReference)
		weaponInstance.visible = true
		weaponInstance.position = Vector3(0.5, -0.25, -0.5)
		Global.currentWeapon = weapons[weapon_index]
		print(Global.currentWeapon)
	else:
		print('weapon index fetch unsuccessful')
		
func _process(delta: float) -> void:
	pass
