class_name MeleeEnemy
extends Enemy

func perform_attack() -> void:
	if not multiplayer.is_server():
		return
		
	if target_player and target_player.has_method("receive_damage"):
		target_player.rpc("receive_damage", attack_damage)
		print("[Melee Enemy] Hit player for ", attack_damage, " damage.")
