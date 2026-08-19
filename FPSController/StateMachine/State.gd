extends Node
class_name State

signal transitioned(from, to)

var play_char: CharacterBody3D

func enter(char: CharacterBody3D):
	play_char = char

func physics_update(delta):
	pass

## state.gd
#
#extends Node
#
#class_name State
#
#signal transitioned
#
#func enter(_char_reference : CharacterBody3D):
	##enter state
	#pass
	#
#func exit():
	##exit state
	#pass
	#
#func update(_delta : float):
	##process update
	#pass
	#
#func physics_update(_delta : float):
	##physics_process update
	#pass 
