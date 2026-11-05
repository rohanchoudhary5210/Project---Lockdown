class_name DynamicCrosshair
extends Control

## Project: Lockdown - Procedural Dynamic Crosshair
## Drawn entirely with code via _draw(), spreading dynamically with movement and weapon fire.

@export var base_spread: float = 6.0
@export var move_spread_factor: float = 1.4
@export var max_spread: float = 24.0
@export var tick_length: float = 6.0
@export var tick_thickness: float = 1.5
@export var dot_radius: float = 1.5
@export var crosshair_color: Color = Color(1.0, 1.0, 1.0, 0.85)

var _fire_spread: float = 0.0
var _current_spread: float = 6.0
var _player: CharacterBody3D = null

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_current_spread = base_spread
	call_deferred("_connect_player")

func _connect_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as CharacterBody3D
	if _player:
		var weapon = _player.find_child("Pistol", true, false)
		if weapon and weapon.has_signal("fired"):
			if not weapon.fired.is_connected(_on_weapon_fired):
				weapon.fired.connect(_on_weapon_fired)

func _on_weapon_fired(_radius: float) -> void:
	kick(9.0)

func kick(amount: float) -> void:
	_fire_spread = min(_fire_spread + amount, max_spread - base_spread)
	queue_redraw()

func _process(delta: float) -> void:
	if not visible:
		return
	
	# Decay fire spread
	if _fire_spread > 0.0:
		_fire_spread = max(_fire_spread - delta * 36.0, 0.0)
	
	# Calculate target spread based on movement speed
	var target_spread = base_spread + _fire_spread
	if _player and is_instance_valid(_player):
		var horizontal_vel = Vector2(_player.velocity.x, _player.velocity.z).length()
		target_spread += horizontal_vel * move_spread_factor
		if not _player.is_on_floor():
			target_spread += 6.0
	
	target_spread = clampf(target_spread, base_spread, max_spread)
	
	if not is_equal_approx(_current_spread, target_spread):
		_current_spread = lerpf(_current_spread, target_spread, delta * 20.0)
		queue_redraw()

func _draw() -> void:
	# Center dot
	draw_circle(Vector2.ZERO, dot_radius, crosshair_color)
	
	# 4 Crosshair ticks (Top, Bottom, Left, Right)
	var s = _current_spread
	var l = tick_length
	var half_th = tick_thickness * 0.5
	
	# Top tick
	draw_rect(Rect2(-half_th, -s - l, tick_thickness, l), crosshair_color)
	# Bottom tick
	draw_rect(Rect2(-half_th, s, tick_thickness, l), crosshair_color)
	# Left tick
	draw_rect(Rect2(-s - l, -half_th, l, tick_thickness), crosshair_color)
	# Right tick
	draw_rect(Rect2(s, -half_th, l, tick_thickness), crosshair_color)
