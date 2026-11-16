class_name CameraFeedbackData
extends Resource

## Project: Lockdown - Camera Feedback Data Resource
## Controls trauma-based screen shake, FOV kick, and presets.

@export_group("Shake Properties")
@export var trauma_decay_rate: float = 1.6
@export var max_pitch_deg: float = 2.5
@export var max_yaw_deg: float = 2.5
@export var max_roll_deg: float = 3.0
@export var max_offset_x: float = 0.04
@export var max_offset_y: float = 0.04
@export var shake_frequency: float = 24.0

@export_group("FOV Kick Properties")
@export var fov_recovery_speed: float = 10.0

@export_group("Presets: Firing")
@export var fire_trauma: float = 0.16
@export var fire_fov_kick: float = 1.4

@export_group("Presets: Dealing Melee")
@export var melee_hit_trauma: float = 0.35
@export var melee_hit_fov_kick: float = 3.0

@export_group("Presets: Taking Damage")
@export var damage_taken_trauma: float = 0.55
@export var damage_taken_fov_kick: float = -4.0
