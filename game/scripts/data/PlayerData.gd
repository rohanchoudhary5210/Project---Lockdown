class_name PlayerData
extends Resource

## Project: Lockdown - Player Data Resource
## Holds all tunable gameplay, movement, camera, and stance values.

@export_group("Health")
@export var max_health: float = 100.0

@export_group("Movement Speeds")
@export var walk_speed: float = 4.5
@export var sprint_speed: float = 7.0
@export var crouch_speed: float = 2.5
@export var acceleration: float = 18.0
@export var deceleration: float = 22.0
@export var air_control: float = 0.35

@export_group("Jump & Gravity")
@export var jump_velocity: float = 4.8
@export var gravity: float = 15.0

@export_group("Stance Heights")
@export var stand_height: float = 1.8
@export var crouch_height: float = 1.0
@export var stand_camera_height: float = 1.6
@export var crouch_camera_height: float = 0.85
@export var stance_transition_speed: float = 12.0
@export var crouch_toggle_mode: bool = false ## If true, crouch is toggle (mobile-friendly); if false, hold to crouch.

@export_group("Camera & Look Settings")
@export var default_fov: float = 78.0 ## GDD baseline FOV: 78
@export var mouse_sensitivity: float = 0.002
@export var controller_look_speed: float = 3.0
@export var invert_y: bool = false ## Configurable via settings
@export var graphics_quality: String = "High" ## "Low" or "High"

@export_group("Noise Radii (Footsteps)")
@export var noise_walk: float = 3.0
@export var noise_sprint: float = 6.0
@export var noise_crouch: float = 0.0
