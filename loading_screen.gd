extends Control

#@onready.animation_player: AnimationPlayer = $AnimationPlayer # Optional if you want a fade out


func _on_world_ready() -> void:
	print("[LoadingScreen] World is ready. Deleting loading screen...")
	
	# Optional fade out
	#if animation_player and animation_player.has_animation("fade_out"):
		#animation_player.play("fade_out")
		#await animation_player.animation_finished
		
	# Instantly remove the loading screen from memory
	queue_free()
