class_name EnemyData
extends Resource

## Project: Lockdown - Enemy Configuration Data
## Holds all tunable stats for enemy archetypes, perception, movement, and combat.

@export_group("Identity & Health")
@export var enemy_name: String = "Ranged Guard"
@export var max_health: float = 75.0
@export var bullet_damage_multiplier: float = 1.0 ## Multiplier for incoming bullet damage (Rusher: 0.6)

@export_group("Movement")
@export var move_speed_patrol: float = 2.0
@export var move_speed_chase: float = 3.8
@export var search_duration: float = 8.0 ## Duration spent searching last known position

@export_group("Perception & Vision")
@export var vision_range: float = 30.0
@export var vision_fov_degrees: float = 90.0
@export var detection_time_min: float = 0.4 ## Detection fill duration at close distance (seconds)
@export var detection_time_max: float = 1.2 ## Detection fill duration at max vision range (seconds)
@export var crouch_detection_multiplier: float = 0.5 ## Crouch slows detection fill by 50%
@export var detection_decay_rate: float = 1.0 ## Decay rate per second when player leaves vision

@export_group("Ranged Combat")
@export var damage_per_shot: float = 8.0
@export var fire_interval: float = 0.7
@export var reaction_delay: float = 0.5 ## Delay before first shot after spotting player
@export var base_spread_rad: float = 0.04
@export var player_moving_spread_mult: float = 2.2
@export var distance_spread_factor: float = 0.003
@export var gunshot_noise_radius: float = 25.0

@export_group("Melee Combat (Rusher)")
@export var melee_damage: float = 20.0
@export var attack_range: float = 1.6
@export var telegraph_duration: float = 0.4
@export var attack_recovery_time: float = 0.8 ## Punish window after attack
@export var flinch_duration: float = 0.15 ## Movement interrupt on bullet hit
@export var flinch_cooldown: float = 0.6 ## Rusher can flinch at most once every 0.6s
@export var stun_vulnerability_multiplier: float = 1.5 ## Melee damage multiplier while stunned
