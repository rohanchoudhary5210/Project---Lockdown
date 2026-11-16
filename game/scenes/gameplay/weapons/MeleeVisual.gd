class_name MeleeVisual
extends Node3D

## Project: Lockdown - Melee Viewmodel Visual
## Procedural animations for melee strike slash and defensive blocking guard.

@onready var knife_mesh: Node3D = $KnifeModel

var _rest_pos: Vector3 = Vector3(0.18, -0.22, -0.32)
var _rest_rot: Vector3 = Vector3(0.0, 0.0, 0.0)
var _block_pos: Vector3 = Vector3(0.0, -0.12, -0.26)
var _block_rot: Vector3 = Vector3(0.25, -0.4, 0.6)

var is_animating_strike: bool = false
var is_blocking: bool = false

func _ready() -> void:
	position = _rest_pos
	rotation = _rest_rot
	visible = false # Hidden until attacking or blocking

func set_blocking(blocking: bool) -> void:
	is_blocking = blocking
	if is_animating_strike:
		return
	visible = is_blocking

func _process(delta: float) -> void:
	if is_animating_strike:
		return
	
	var target_pos: Vector3 = _block_pos if is_blocking else _rest_pos
	var target_rot: Vector3 = _block_rot if is_blocking else _rest_rot
	
	position = position.lerp(target_pos, 16.0 * delta)
	rotation = rotation.lerp(target_rot, 16.0 * delta)
	
	if not is_blocking and position.distance_to(_rest_pos) < 0.01:
		visible = false

func play_attack_animation() -> void:
	is_animating_strike = true
	visible = true
	
	# Swift slash forward and across
	position = Vector3(0.25, -0.15, -0.2)
	rotation = Vector3(-0.3, 0.6, -0.5)
	
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "position", Vector3(-0.15, -0.18, -0.42), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation", Vector3(0.4, -0.5, 0.8), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	await tween.finished
	
	var return_tween: Tween = create_tween().set_parallel(true)
	var end_pos = _block_pos if is_blocking else _rest_pos
	var end_rot = _block_rot if is_blocking else _rest_rot
	return_tween.tween_property(self, "position", end_pos, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	return_tween.tween_property(self, "rotation", end_rot, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	
	await return_tween.finished
	is_animating_strike = false
	if not is_blocking:
		visible = false
