class_name InteractIcon
extends Control

## Procedurally drawn interact prompt diamond icon
@export var border_color: Color = Color(0.3, 0.75, 1.0, 0.9)
@export var fill_color: Color = Color(1.0, 1.0, 1.0, 0.85)

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(18, 18)

func _draw() -> void:
	var w = size.x
	var h = size.y
	var cx = w * 0.5
	var cy = h * 0.5
	var r = min(w, h) * 0.45
	
	# Diamond outline
	var diamond_pts = PackedVector2Array([
		Vector2(cx, cy - r),
		Vector2(cx + r, cy),
		Vector2(cx, cy + r),
		Vector2(cx - r, cy),
		Vector2(cx, cy - r)
	])
	draw_polyline(diamond_pts, border_color, 1.5, true)
	
	# Inner dot
	draw_circle(Vector2(cx, cy), 2.2, fill_color)
