@tool
extends Control

const sprite_size = Vector2(32, 32)

@export var line_colour: Color
@export var background_colour: Color
@export var highlight_colour: Color
@export var outer_radius: int = 256
@export var inner_radius: int = 64
@export var line_width: int = 4
@export var options: Array[EmoteWheel] = []
var selection = 0

func _draw():
	
	var offset = sprite_size / -2
	
	draw_circle(Vector2.ZERO, outer_radius, background_colour)
	draw_arc(Vector2.ZERO, inner_radius, 0, TAU, 128, line_colour, line_width, true)
	
	if len(options) >= 3:
		for i in range(len(options) - 1):
			var rads = TAU * i / (len(options) - 1)
			var point = Vector2.from_angle(rads)
			draw_line(point*inner_radius, point*outer_radius, line_colour, line_width)
		
		draw_texture_rect_region(
			options[0].atlas,
			Rect2(offset, sprite_size),
			options[0].region
		)
		
		if selection == 0:
			draw_circle(Vector2.ZERO, inner_radius, highlight_colour)
		
		
		for i in range(1, len(options)):
			var start_rads = (TAU * (i-1)) / (len(options) - 1)
			var end_rads = (TAU * i) / (len(options) - 1)
			var mid_rads = (start_rads + end_rads)/2.0 * -1
			var radius_mid = (inner_radius + outer_radius) / 2
			
			if selection == i:
				var point_per_arc = 32
				var points_inner = PackedVector2Array()
				var points_outer = PackedVector2Array()
				
				for j in range(point_per_arc+1):
					var angle = start_rads + j * (end_rads - start_rads) / point_per_arc
					points_inner.append(inner_radius * Vector2.from_angle(TAU - angle))
					points_outer.append(outer_radius * Vector2.from_angle(TAU - angle))
				
				points_outer.reverse()
				draw_polygon(points_inner + points_outer, PackedColorArray([highlight_colour]))
			
			var draw_pos = radius_mid * Vector2.from_angle(mid_rads) + offset
			draw_texture_rect_region(
				options[i].atlas,
				Rect2(draw_pos, sprite_size),
				options[i].region
			)

func _process(delta):
	var mouse_pos = get_local_mouse_position()
	var mouse_radius = mouse_pos.length()
	
	if mouse_radius < inner_radius:
		selection = 0
	else:
		var mouse_rads = fposmod(mouse_pos.angle() * -1, TAU)
		selection = ceil((mouse_rads / TAU) * (len(options) - 1))
	
	#print(selection)
	
	queue_redraw()
