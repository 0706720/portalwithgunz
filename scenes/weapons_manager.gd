extends Node

# .. is simply a reference to the parent node.
@onready var pistolNode = ^"../Camera3D/Pistol"
@onready var shotgunNode = ^"../Camera3D/Propulsion_shotgun"
@onready var grappleNode = ^"../Camera3D/Grapple Hook"

var weapons = ["Pistol", "Shotgun", "GrappleGun"]

var paths = [
	"res://scenes/models/Pistol.glb", 
	"res://assets/images/Weapons/Shotgunz/spas12.FBX",
	"res://assets/images/Weapons/Vacuum Cleanerz/vacuum3.fbx"]

var nodepaths = [^"../Camera3D/Pistol", ^"../Camera3D/Propulsion_shotgun", ^"../Camera3D/Grapple Hook"]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print(weapons[0])

func print(weapon_index):
	var weaponInstance
	for i in nodepaths:
		weaponInstance = get_node(i)
		weaponInstance.visible = false
		
	var nodeReference = nodepaths[weapon_index]
	weaponInstance = get_node(nodeReference)
	weaponInstance.visible = true
	Global.currentWeapon = weapons[weapon_index]
	print(Global.currentWeapon)
		
		
	# should return pistol, shotgun or grapplegun since parameter should be 0, 1 or 2. 2
	#var index = weapons[weapon_index]
	#var path = paths[weapon_index]
	#var nodeReference = nodepaths[weapon_index]
	#var weaponInstance = get_node(nodeReference)
	#if weaponInstance:
	#weaponInstance.visible = false
	#print(weaponInstance.visible)
	#else:
		#print('failure')
	
	
	#var new_enemies = preload("res://new _round.tscn")
	#instantiate a new set of enemies, but not reload the scene entirely
	#current_round = new_enemies.instantiate()
	#current_round.position = Vector2(0, 0)
	#get_tree().get_root().add_child(current_round)
	
	
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
