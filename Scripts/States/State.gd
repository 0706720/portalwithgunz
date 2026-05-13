# state.gd
class_name State
extends Node

# This declaration allows all children (Idle/Walking) to access it
var state_machine = null

# Using 'owner' allows the state to control the Player (CharacterBody3D)
@onready var player = owner 

func enter():
	pass

func exit():
	pass

func update(_delta):
	pass

func physics_update(_delta):
	pass
