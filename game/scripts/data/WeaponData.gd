class_name WeaponData
extends Resource

## Project: Lockdown - Weapon Data Resource
## Defines all tunable values for firearms (stats, ammo, handling, feedback, recoil).

@export_group("Identity & Combat Stats")
@export var weapon_name: String = "Pistol"
@export var damage: float = 25.0
@export var max_range: float = 100.0
@export var fire_interval: float = 0.18 ## Rate of fire interval in seconds
@export var gunshot_noise_radius: float = 25.0

@export_group("Ammunition & Reloading")
@export var mag_capacity: int = 12
@export var reserve_capacity: int = 48
@export var max_reserve: int = 72 ## Maximum reserve ammunition capacity
@export var starting_ammo_in_mag: int = 12
@export var starting_reserve_ammo: int = 48
@export var reload_time: float = 1.4 ## Reload duration in seconds
@export var auto_reload_on_empty: bool = true ## Automatically initiates reload when firing on empty magazine

@export_group("Camera Recoil Kick")
@export var recoil_pitch: float = 0.035 ## Upward camera pitch kick in radians
@export var recoil_yaw_random: float = 0.01 ## Random horizontal camera kick
@export var recoil_recovery_speed: float = 10.0 ## Speed at which camera recovers from recoil
@export var recoil_multiplier_touch: float = 0.45 ## Recoil multiplier applied on touchscreen devices (default 0.45)

@export_group("Viewmodel Handling & Kick")
@export var viewmodel_kick_pos: Vector3 = Vector3(0.0, 0.02, 0.08) ## Backward/up displacement on fire
@export var viewmodel_kick_rot: Vector3 = Vector3(0.12, 0.0, 0.0) ## Upward rotation kick on fire
@export var viewmodel_recovery_speed: float = 14.0

@export_group("Feedback & Hitstop")
@export var hitstop_duration: float = 0.03 ## Hitstop duration on enemy hit
@export var camera_trauma: float = 0.16
@export var camera_fov_kick: float = 1.4
