class_name DamageDirectionIndicator
extends Control

## Project: Lockdown - Damage Direction Indicator
## Red arcs around the screen center pointing toward whoever hit the player.
## Each arc tracks its attacker while it fades, so turning toward the threat moves the arc to the top.

@export var duration: float = 1.0
@export var radius_ratio: float = 0.32 # of the smaller screen side
@export var arc_degrees: float = 50.0
@export var thickness: float = 10.0
@export var color: Color = Color(0.95, 0.12, 0.08, 0.85)

var _hits: Array[Dictionary] = [] # { source: Node3D, last_pos: Vector3, time_left: float }


## Adds (or refreshes) an arc for this attacker. Hits with no 3D source show nothing.
func add_hit(source: Node) -> void:
	if not (source is Node3D):
		return
	for h in _hits:
		if h.source == source:
			h.time_left = duration
			h.last_pos = source.global_position
			return
	_hits.append({ "source": source, "last_pos": source.global_position, "time_left": duration })
	queue_redraw()

func clear() -> void:
	_hits.clear()
	queue_redraw()

func _process(delta: float) -> void:
	if _hits.is_empty():
		return
	for i in range(_hits.size() - 1, -1, -1):
		var h: Dictionary = _hits[i]
		h.time_left -= delta
		if is_instance_valid(h.source):
			h.last_pos = h.source.global_position
		if h.time_left <= 0.0:
			_hits.remove_at(i)
	queue_redraw()

## Screen angle of a world position as seen by the camera: 0 = straight ahead (top of screen),
## +PI/2 = right, PI = behind (bottom).
static func screen_angle_to(camera: Camera3D, world_pos: Vector3) -> float:
	var local: Vector3 = camera.global_transform.basis.inverse() * (world_pos - camera.global_position)
	return atan2(local.x, -local.z)

func _draw() -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * radius_ratio
	var half_arc: float = deg_to_rad(arc_degrees) * 0.5
	for h in _hits:
		# Screen angles start at "up" (-Y), so shift by -PI/2 for draw_arc's 0 = +X convention.
		var a: float = screen_angle_to(cam, h.last_pos) - PI * 0.5
		var col: Color = color
		col.a *= clampf(h.time_left / duration, 0.0, 1.0)
		draw_arc(center, radius, a - half_arc, a + half_arc, 24, col, thickness, true)
