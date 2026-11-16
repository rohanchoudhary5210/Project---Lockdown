class_name AmmoIcon
extends Control

## Procedurally drawn ammunition cartridge icon
@export var bullet_color: Color = Color(0.95, 0.75, 0.25)
@export var casing_color: Color = Color(0.85, 0.65, 0.2)

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(16, 18)

func set_icon_color(c: Color) -> void:
	bullet_color = c
	casing_color = c * 0.85
	queue_redraw()

func _draw() -> void:
	var w = size.x
	var h = size.y
	var cx = w * 0.5
	var bw = w * 0.45
	
	# Bullet tip (pointed polygon)
	var tip_pts = PackedVector2Array([
		Vector2(cx - bw * 0.5, h * 0.35),
		Vector2(cx, h * 0.05),
		Vector2(cx + bw * 0.5, h * 0.35)
	])
	draw_colored_polygon(tip_pts, bullet_color)
	
	# Bullet casing body
	draw_rect(Rect2(cx - bw * 0.5, h * 0.35, bw, h * 0.5), casing_color)
	
	# Rim at the base
	draw_rect(Rect2(cx - bw * 0.65, h * 0.85, bw * 1.3, h * 0.1), casing_color * 1.1)
