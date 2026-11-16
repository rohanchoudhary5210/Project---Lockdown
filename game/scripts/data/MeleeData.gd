class_name MeleeData
extends Resource

## Project: Lockdown - Melee Combat Data Resource
## Controls damage, range, cooldown, block damage mitigation, and parry windows.

@export_group("Attack Properties")
@export var damage: float = 35.0
@export var attack_range: float = 1.8 ## Hit detection range in meters
@export var cooldown: float = 0.6 ## Attack recovery cooldown in seconds
@export var attack_noise_radius: float = 4.0

@export_group("Block & Parry")
@export var block_damage_reduction: float = 0.70 ## Mitigates 70% melee damage while blocking
@export var parry_window: float = 0.25 ## Parry window in seconds from block initiation
@export var parry_stun_duration: float = 1.5 ## Stun duration applied to enemy upon parry

@export_group("Feedback & Hitstop")
@export var melee_hitstop: float = 0.06 ## Hitstop duration on melee strike impact
@export var parry_hitstop: float = 0.08 ## Hitstop duration on successful parry
@export var camera_trauma: float = 0.35
@export var camera_fov_kick: float = 3.0
