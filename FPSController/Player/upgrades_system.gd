extends Node
# the syntax '../..' means to go up twice in the scene tree, which finds player
@onready var xpBar = %xpBar
@onready var UI: Control = %HUD
@onready var camera = %Camera3D

# rarity values are as follows: 1 for common, 2 for rare, 3 for legendary (if we do those).
@export var card_pool: Array[Dictionary] = [
	{ "name": "speed_up", "scene": preload("res://assets/models/upgradeCards/commom/speed_up_card.tscn"), "rarity": 1, "unique": false },
	{ "name": "health_up", "scene": preload("res://assets/models/upgradeCards/commom/health_up_card.tscn"), "rarity": 1, "unique": false },
	{ "name": "damage_up", "scene": preload("res://assets/models/upgradeCards/commom/damage_up_card.tscn"), "rarity": 1, "unique": false },
	{ "name": "unlock_jump", "scene": preload("res://assets/models/upgradeCards/rare/unlock_jump_card.tscn"), "rarity": 2, "unique": true },
	{ "name": "unlock_grenade_launcher", "scene": preload("res://assets/models/upgradeCards/rare/unlock_grenade_launcher.tscn"), "rarity": 2, "unique": true },
	{ "name": "unlock_shotugn", "scene": preload("res://assets/models/upgradeCards/rare/unlock_shotgun.tscn"), "rarity": 2, "unique": true },
	{ "name": "xp_threshold", "scene": preload("res://assets/models/upgradeCards/rare/xp_threshold_card.tscn"), "rarity": 2, "unique": true },
	{ "name": "large_health_up", "scene": preload("res://assets/models/upgradeCards/rare/large_health_up_card.tscn"), "rarity": 2, "unique": false },
	{ "name": "large_speed_up", "scene": preload("res://assets/models/upgradeCards/rare/large_speed_up_card.tscn"), "rarity": 2, "unique": false },
]

var failsafe = 0
var modified_cards

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	xpBar.level_up.connect(_add_options)
	modified_cards = card_pool.duplicate(true)
	# this should ensure random output is different every run
	randomize()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _add_options(input):
# intended logic: use the upgradesNode to 'paste' 3 random options out of the cards available onto 
# each player's screens locally, every roll seperate.
	#print('found signal and func ran: ' + str(input))
	# how many upgrades per person
	var options = 3
	var spawned_card
	var card_object
	modified_cards = card_pool.duplicate(true)
	
	for index in options:
		# this will be used for weighting: 0-7 means a common spawns whilst 8-10 means rare
		var rarity_rng = randi_range(0, 10)
		if rarity_rng == 8:
			card_object = validate_index(1)
			spawned_card = card_object["scene"].instantiate()
		else:
			card_object = validate_index(2)
			spawned_card = card_object["scene"].instantiate()
		
		failsafe = 0
		var pos
		# match keyword is shorthand for an else-if statement. It will check for
		# the value of index, and adjust x position accordingly
		match index:
			0:
				pos = -220
			1:
				pos = 130
			2:
				pos = 480

		spawned_card.position = Vector2(pos, 80)
		UI.add_child(spawned_card)
		print("card: " + str(spawned_card))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func validate_index(rarity):
	failsafe += 1
	var index_rng = randi_range(0, modified_cards.size() - 1)
	#var arraypos = rng % card_pool.size()
	#print('cardpool size: ' + str(modified_cards.size()) + ' and rng is: ' +str(index_rng) + ' and rarity is: ' + str(rarity))
	# grabs the random card rolled using 'get'
	var check_element = modified_cards.get(index_rng)
	#print(check_element)
	# for example, a card must be a common if the required rarity is common. Otherwise, 
	# the 'else' runs and the function calls itself.
	if check_element['rarity'] == rarity:
		modified_cards.remove_at(index_rng)
		var index = card_pool.find(check_element)
		return card_pool[index]
	else:
		if failsafe >= 10:
			#print('FAILSAFE REACHED')
			return card_pool[0]
		#print("FAILED")
		return validate_index(rarity)
		
func unlock_shotgun():
	card_pool.append({
		"name": "shotgun_damage",
		"scene": preload("res://assets/models/upgradeCards/rare/shotgun_damage_card.tscn"),
		"rarity": 2,
		"unique": true
	})
	card_pool.append({
		"name": "shotgun_cooldown",
		"scene": preload("res://assets/models/upgradeCards/rare/shotgun_cooldown_card.tscn"),
		"rarity": 2,
		"unique": true
	})

func unlock_grenade_launcher():
	card_pool.append({
		"name": "grenade_radius",
		"scene": preload("res://assets/models/upgradeCards/rare/grenade_radius_card.tscn"),
		"rarity": 2,
		"unique": true
	})
	card_pool.append({
		"name": "grenade_damage",
		"scene": preload("res://assets/models/upgradeCards/rare/grenade_damage_card.tscn"),
		"rarity": 2,
		"unique": true
	})
	
func unlock_jump():
	card_pool.append({
		"name": "jump_cooldown",
		"scene": preload("res://assets/models/upgradeCards/rare/jump_cooldown_card.tscn"),
		"rarity": 2,
		"unique": true
	})
	card_pool.append({
		"name": "jump_distance",
		"scene": preload("res://assets/models/upgradeCards/rare/jump_distance_card.tscn"),
		"rarity": 2,
		"unique": true
	})

func clear_unique(cardname: String):
	# fancy line which finds index where name = parameter
	var index = card_pool.find_custom(func(card): return card["name"] == cardname)
	card_pool.remove_at(index)
	
	
	
