extends Node
# the syntax '../..' means to go up twice in the scene tree, which finds player
@onready var player = get_node("../..")
@onready var UI: Control = %HUD
@onready var camera = %Camera3D

# rarity values are as follows: 1 for common, 2 for rare, 3 for legendary (if we do those).
@export var card_pool: Array[Dictionary] = [
	{ "scene": preload("res://assets/models/upgradeCards/commom/speed_up_card.tscn"), "rarity": 1 },
	{ "scene": preload("res://assets/models/upgradeCards/commom/health_up_card.tscn"), "rarity": 1 },
	{ "scene": preload("res://assets/models/upgradeCards/commom/damage_up_card.tscn"), "rarity": 1 },
	{ "scene": preload("res://assets/models/upgradeCards/rare/unlock_jump.tscn"), "rarity": 2 },
]

const speedupcard = preload("res://assets/models/upgradeCards/commom/speed_up_card.tscn")
const healthupcard = preload("res://assets/models/upgradeCards/commom/health_up_card.tscn")
const damageupcard = preload("res://assets/models/upgradeCards/commom/damage_up_card.tscn")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	player.level_up.connect(_add_options)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _add_options(input):
	var screen_center := UI.size / 2.0
# intended logic: use the upgradesNode to 'paste' 3 random options out of the cards available onto 
# each player's screens locally, every roll seperate.
	print('found signal and func ran: ' + str(input))
	# how many upgrades per person
	var options = 3
	var spawned_card
	for index in options:
		# this should ensure random output is different every run
		randomize()
		# this will be used for weighting: 0-7 means a common spawns whilst 8-10 means rare
		var rng = randi_range(0, 10)
		if rng <= 7:
			for card in card_pool:
				if card["rarity"] == 1: 
					spawned_card = card["scene"].instantiate()
					break
		else:
			for card in card_pool:
				if card["rarity"] == 2: 
					spawned_card = card["scene"].instantiate()
					break
		
		#var spawned_card = speedupcard.instantiate()
		# Center the card in the viewport
		spawned_card.position = screen_center
		UI.add_child(spawned_card)
		
