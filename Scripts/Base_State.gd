#base_state.gd
class_name State
extends Node

signal state_finished(next_state_name: StringName)

var player: CharacterBody3D
var state_machine: StateMachine

func enter() -> void:
	pass

func exit() -> void:
	pass

func _physics_update(_delta: float) -> void:
	pass

func Update(_delta) -> void:
	pass
