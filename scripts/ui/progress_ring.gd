class_name ProgressRing
extends Control

## Project: Lockdown - Radial Progress Ring
## Resolution-independent GPU arc draw around the crosshair.
## Used for holding interactions such as teammate rescue.

@export var radius: float = 22.0
@export var width: float = 3.0
@export var ring_color: Color = Color(0.25, 0.85, 1.0, 0.95)
@export var bg_color: Color = Color(0.1, 0.15, 0.2, 0.5)

var progress: float = 0.0:
	set(val):
		progress = clampf(val, 0.0, 1.0)
		queue_redraw()

func _draw() -> void:
	if progress <= 0.0:
		return
	
	var center = size * 0.5
	# Draw background circle
	draw_arc(center, radius, 0.0, TAU, 48, bg_color, width, true)
	
	# Draw progress arc clockwise from 12 o'clock (-PI / 2)
	var start_angle: float = -PI * 0.5
	var end_angle: float = start_angle + progress * TAU
	draw_arc(center, radius, start_angle, end_angle, 48, ring_color, width, true)
