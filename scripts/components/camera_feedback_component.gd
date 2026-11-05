class_name CameraFeedbackComponent
extends Node

## Project: Lockdown - Camera Feedback Component
## Manages trauma-based camera shake and dynamic FOV kicks.
## Values are configured via CameraFeedbackData resource.

@export var feedback_data: CameraFeedbackData
@export var target_camera: Camera3D

var trauma: float = 0.0
var fov_offset: float = 0.0
var base_fov: float = 78.0
var _noise_time: float = 0.0

func _ready() -> void:
	if not feedback_data:
		feedback_data = preload("res://data/default_camera_feedback_data.tres")
	
	if not target_camera:
		if get_parent() is Camera3D:
			target_camera = get_parent() as Camera3D
		elif get_node_or_null("../Camera3D"):
			target_camera = get_node("../Camera3D")
	
	if target_camera:
		base_fov = target_camera.fov

func _process(delta: float) -> void:
	if not target_camera:
		return
	
	_noise_time += delta * feedback_data.shake_frequency
	
	# Trauma decay
	if trauma > 0.0:
		trauma = max(trauma - feedback_data.trauma_decay_rate * delta, 0.0)
		var shake_amount: float = trauma * trauma # Non-linear shake response
		
		var pitch_shake: float = sin(_noise_time * 1.1) * deg_to_rad(feedback_data.max_pitch_deg) * shake_amount
		var yaw_shake: float = cos(_noise_time * 0.9) * deg_to_rad(feedback_data.max_yaw_deg) * shake_amount
		var roll_shake: float = sin(_noise_time * 1.4) * deg_to_rad(feedback_data.max_roll_deg) * shake_amount
		
		target_camera.rotation.x = pitch_shake
		target_camera.rotation.y = yaw_shake
		target_camera.rotation.z = roll_shake
		
		var offset_x: float = cos(_noise_time * 1.3) * feedback_data.max_offset_x * shake_amount
		var offset_y: float = sin(_noise_time * 1.5) * feedback_data.max_offset_y * shake_amount
		target_camera.position = Vector3(offset_x, offset_y, 0.0)
	else:
		target_camera.rotation = Vector3.ZERO
		target_camera.position = Vector3.ZERO
	
	# FOV recovery
	if abs(fov_offset) > 0.01:
		fov_offset = lerp(fov_offset, 0.0, feedback_data.fov_recovery_speed * delta)
		target_camera.fov = base_fov + fov_offset
	else:
		fov_offset = 0.0
		target_camera.fov = base_fov

func add_trauma(amount: float) -> void:
	trauma = clamp(trauma + amount, 0.0, 1.0)

func kick_fov(amount: float) -> void:
	fov_offset += amount

func apply_fire_feedback() -> void:
	if not feedback_data:
		return
	add_trauma(feedback_data.fire_trauma)
	kick_fov(feedback_data.fire_fov_kick)

func apply_melee_hit_feedback() -> void:
	if not feedback_data:
		return
	add_trauma(feedback_data.melee_hit_trauma)
	kick_fov(feedback_data.melee_hit_fov_kick)

func apply_damage_taken_feedback() -> void:
	if not feedback_data:
		return
	add_trauma(feedback_data.damage_taken_trauma)
	kick_fov(feedback_data.damage_taken_fov_kick)
