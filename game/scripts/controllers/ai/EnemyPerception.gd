class_name EnemyPerception
extends Node3D

## Project: Lockdown - Enemy Perception Component (Vision & Hearing)
## Handles non-instant vision cone detection (0.4s close to 1.2s far, 50% slower for crouching),
## line-of-sight raycasts, and acoustic sensing via NoiseBus.

signal detection_meter_changed(meter_value: float)
signal player_spotted(last_known_pos: Vector3)
signal player_lost(last_known_pos: Vector3)
signal noise_heard(noise_pos: Vector3, noise_radius: float, source: Node)

@export var enemy_data: EnemyData

var detection_meter: float = 0.0 ## Normalized 0.0 to 1.0
var has_line_of_sight: bool = false
var is_player_spotted: bool = false
var last_known_player_position: Vector3 = Vector3.ZERO
var player_ref: CharacterBody3D = null
var last_heard_noise_radius: float = 0.0
var last_heard_noise_blocked: bool = false
var last_heard_timer: float = 0.0

func _ready() -> void:
	if not enemy_data:
		enemy_data = preload("res://game/assets/data/ranged_enemy_data.tres")
	
	call_deferred("_connect_noise_bus")

func _connect_noise_bus() -> void:
	var nb = get_node_or_null("/root/NoiseBus")
	if nb and nb.has_signal("noise_emitted"):
		nb.noise_emitted.connect(_on_noise_emitted)

func _process(delta: float) -> void:
	if last_heard_timer > 0.0:
		last_heard_timer = maxf(0.0, last_heard_timer - delta)
	
	if not player_ref:
		player_ref = get_tree().get_first_node_in_group("player") as CharacterBody3D
		if not player_ref:
			return
	
	if "is_dead" in player_ref and player_ref.is_dead:
		_decay_detection(delta)
		return
	
	_update_vision(delta)

func _update_vision(delta: float) -> void:
	var enemy: Node3D = get_parent() as Node3D
	if not enemy:
		return
	
	var eye_pos: Vector3 = enemy.global_position + Vector3(0, 1.5, 0)
	var player_target_pos: Vector3 = player_ref.global_position + Vector3(0, 1.0, 0)
	var to_player: Vector3 = player_target_pos - eye_pos
	var distance: float = to_player.length()
	
	var in_range: bool = distance <= enemy_data.vision_range
	var in_cone: bool = false
	
	if in_range and distance > 0.1:
		var forward: Vector3 = -enemy.global_transform.basis.z.normalized()
		var dir_to_player: Vector3 = to_player.normalized()
		var angle_rad: float = forward.angle_to(dir_to_player)
		var half_fov_rad: float = deg_to_rad(enemy_data.vision_fov_degrees * 0.5)
		in_cone = angle_rad <= half_fov_rad
	
	has_line_of_sight = false
	if in_range and in_cone:
		has_line_of_sight = _cast_los_ray(eye_pos, player_target_pos)
	
	if has_line_of_sight:
		last_known_player_position = player_ref.global_position
		
		# Detection meter fill calculation: 0.4s (close) to 1.2s (far edge)
		var dist_fraction: float = clampf(distance / enemy_data.vision_range, 0.0, 1.0)
		var fill_time: float = lerpf(enemy_data.detection_time_min, enemy_data.detection_time_max, dist_fraction)
		var fill_rate: float = 1.0 / maxf(fill_time, 0.05)
		
		# Crouching player fills detection meter 50% slower
		if "is_crouching" in player_ref and player_ref.is_crouching:
			fill_rate *= enemy_data.crouch_detection_multiplier
		
		detection_meter = minf(1.0, detection_meter + fill_rate * delta)
		detection_meter_changed.emit(detection_meter)
		
		if detection_meter >= 1.0 and not is_player_spotted:
			is_player_spotted = true
			player_spotted.emit(last_known_player_position)
	else:
		_decay_detection(delta)

func _decay_detection(delta: float) -> void:
	if detection_meter > 0.0:
		detection_meter = maxf(0.0, detection_meter - enemy_data.detection_decay_rate * delta)
		detection_meter_changed.emit(detection_meter)
	
	if is_player_spotted and not has_line_of_sight:
		# Player broken line of sight; trigger player_lost with last known location
		is_player_spotted = false
		player_lost.emit(last_known_player_position)

func reset_perception() -> void:
	detection_meter = 0.0
	has_line_of_sight = false
	is_player_spotted = false
	last_known_player_position = Vector3.ZERO
	last_heard_noise_radius = 0.0
	last_heard_noise_blocked = false
	last_heard_timer = 0.0
	detection_meter_changed.emit(0.0)

func _cast_los_ray(from_pos: Vector3, to_pos: Vector3) -> bool:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.collision_mask = 1 | 2 # World (layer 1) + Player (layer 2)
	
	var enemy = get_parent()
	if enemy is CollisionObject3D:
		query.exclude = [enemy.get_rid()]
	
	var result: Dictionary = space_state.intersect_ray(query)
	if result:
		var collider: Node = result.collider
		if collider == player_ref:
			return true
		if player_ref.is_ancestor_of(collider):
			return true
	return false

func _is_noise_occluded(noise_pos: Vector3, enemy: Node3D) -> bool:
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	if not space_state:
		return false
	
	var ear_pos: Vector3 = enemy.global_position + Vector3(0, 1.5, 0)
	var from_pos: Vector3 = noise_pos + Vector3(0, 0.1, 0)
	var query := PhysicsRayQueryParameters3D.create(from_pos, ear_pos)
	query.collision_mask = 1 # World layer only (physics layer 1)
	
	var result: Dictionary = space_state.intersect_ray(query)
	return not result.is_empty()

func _on_noise_emitted(pos: Vector3, radius: float, source: Node, noise_type: String = "generic") -> void:
	var enemy: Node3D = get_parent() as Node3D
	if not enemy or source == enemy:
		return
	
	# Raycast occlusion check (world layer only) from noise to enemy's ears
	var is_blocked: bool = _is_noise_occluded(pos, enemy)
	
	# Determine if this sound is a footstep
	var is_footstep: bool = (noise_type == "footstep") or (noise_type == "generic" and radius <= 6.0 and source != null and source.is_in_group("player"))
	
	# Footsteps that are blocked are not heard at all
	if is_blocked and is_footstep:
		return
	
	# If blocked, effective radius is multiplied by 0.4 (sound muffled by walls)
	var effective_radius: float = radius
	if is_blocked:
		effective_radius = radius * 0.4
	
	var dist: float = enemy.global_position.distance_to(pos)
	if dist <= effective_radius:
		last_known_player_position = pos
		last_heard_noise_radius = effective_radius
		last_heard_noise_blocked = is_blocked
		last_heard_timer = 3.0
		noise_heard.emit(pos, effective_radius, source)
