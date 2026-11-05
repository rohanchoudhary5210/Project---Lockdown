class_name HealthIcon
extends Control

## Procedurally drawn health cross icon
@export var icon_color: Color = Color(0.3, 0.9, 0.6)

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(18, 18)

func set_icon_color(c: Color) -> void:
	icon_color = c
	queue_redraw()

func _draw() -> void:
	var w = size.x
	var h = size.y
	var bar_w = w * 0.3
	var bar_h = h * 0.3
	
	# Horizontal bar of cross
	draw_rect(Rect2((w - w * 0.85) * 0.5, (h - bar_h) * 0.5, w * 0.85, bar_h), icon_color)
	# Vertical bar of cross
	draw_rect(Rect2((w - bar_w) * 0.5, (h - h * 0.85) * 0.5, bar_w, h * 0.85), icon_color)
