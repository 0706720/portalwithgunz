extends Node3D

@onready var viewport: SubViewport = $SubViewportContainer/SubViewport

func _ready() -> void:
	await RenderingServer.frame_post_draw

	var image := viewport.get_texture().get_image()
	image.save_png("user://grapple_2d.png")

	print("Saved to: ", OS.get_user_data_dir())
