extends Node

@onready var main_menu = $CanvasLayer/MainMenu
@onready var address_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AddressEntry
@onready var hud = $CanvasLayer/HUD

@onready var PlayerScene := preload("res://scenes/player.tscn")

const PORT := 9999
var peer := ENetMultiplayerPeer.new()

func _ready():
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
#-------------------------
#HOST
#-------------------------

func _on_host_button_pressed():
	main_menu.hide()
	hud.show()

	peer.create_server(PORT)
	multiplayer.multiplayer_peer = peer

# Spawn host player
	_spawn_player(multiplayer.get_unique_id())

#-------------------------
#CLIENT
#-------------------------

func _on_join_button_pressed():
	main_menu.hide()
	hud.show()

	peer.create_client(address_entry.text, PORT)
	multiplayer.multiplayer_peer = peer

#-------------------------
#SPAWNING
#-------------------------

func _on_peer_connected(id):
	_spawn_player(id)

func _on_peer_disconnected(id):
	var p := get_node_or_null(str(id))
	if p:
		p.queue_free()

func _spawn_player(id):
	var player := PlayerScene.instantiate()
	player.name = str(id)
	player.set_multiplayer_authority(id)
	add_child(player)
#extends Node
#
#@onready var main_menu = $CanvasLayer/MainMenu
#@onready var address_entry = $CanvasLayer/MainMenu/MarginContainer/VBoxContainer/AddressEntry
#@onready var hud = $CanvasLayer/HUD
#@onready var health_bar = $CanvasLayer/HUD/HealthBar
#
#
#@onready var Player = preload("res://scenes/player.tscn")
##@onready var Player = $Player
#var tracked = false
#var player
#
#
#const PORT = 9999
#var enet_peer = ENetMultiplayerPeer.new()
#
#
#func _on_host_button_pressed():
	#main_menu.hide()
	#hud.show()
	#
	#enet_peer.create_server(PORT)
	#multiplayer.multiplayer_peer = enet_peer
	#multiplayer.peer_connected.connect(add_player)
	#multiplayer.peer_disconnected.connect(remove_player)
	#
	#add_player(multiplayer.get_unique_id())
	#
	##upnp_setup()
#func _on_join_button_pressed():
	#main_menu.hide()
	#hud.show()
	#
	#enet_peer.create_client(address_entry.text, PORT)
	#multiplayer.multiplayer_peer = enet_peer
#
#func _on_multiplayer_spawner_spawned(node):
	#if node.is_multiplayer_authority():
		#pass
		##node.health_changed.connect(update_health_bar)
#
#func upnp_setup():
	#var upnp = UPNP.new()
	#
	#var discover_result = upnp.discover()
	#assert(discover_result == UPNP.UPNP_RESULT_SUCCESS, "UPNP Discover Failed! Error %s" % discover_result)
#
	#assert(upnp.get_gateway() and upnp.get_gateway().is_valid_gateway(), "UPNP Invalid Gateway!")
#
	#var map_result = upnp.add_port_mapping(PORT)
	#assert(map_result == UPNP.UPNP_RESULT_SUCCESS, "UPNP Port Mapping Failed! Error %s" % map_result)
	#
	#print("Success! Join Address: %s" % upnp.query_external_address())
#
#
#func _ready() -> void:
	#Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	#var target_node = get_node("Target")
	#if target_node:
		#target_node.update_score.connect(_on_target_destroyed)
		#print('target signal connect successful')
#
#func _on_target_destroyed(am):
	#Global.current_score += 10
	#print('current score is ' + str(Global.current_score))
#
#func _physics_process(delta):
	#if tracked:
		#get_tree().call_group("enemy", "update_target_location", player.global_transform.origin)
#
#func _unhandled_input(event):
	#if Input.is_action_just_pressed("quit"):
		#get_tree().quit()
#
#func _on_single_player_button_pressed():
	#main_menu.hide()
	#hud.show()
	#multiplayer.multiplayer_peer = enet_peer
	#add_player(multiplayer.get_unique_id())
#
#
#func add_player(peer_id):
	#player = Player.instantiate()
	#player.name = str(peer_id)
	#add_child(player)
	#tracked = true
	#if player.is_multiplayer_authority():
		#pass
		##player.health_changed.connect(update_health_bar)
#
#func remove_player(peer_id):
	#var player = get_node_or_null(str(peer_id))
	#if player:
		#player.queue_free()
#
#
#func _on_map_1_pressed() -> void:
	#get_tree().change_scene_to_file("res://Map.tscn")
#
#
#func _on_single_player_pressed() -> void:
	#pass # Replace with function body.
