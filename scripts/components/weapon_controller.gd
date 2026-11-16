class_name WeaponController
extends Node3D

## Project: Lockdown - Weapon Controller (Milestone 2)
## Handles firearm shooting, raycast hit detection, ammo tracking, reloading,
## recoil kick, dry fire, hitstop, and placeholder muzzle flash.
## Strictly respects InputMap actions; communicates via signals.

signal ammo_changed(current_mag: int, reserve: int)
signal fired(gunshot_noise_radius: float)
signal dry_fired()
signal reload_started(duration: float)
signal reload_completed()
signal hit_target(target: Node, hit_position: Vector3, normal: Vector3, damage: float)
signal damage_dealt(target: Node, killed: bool) # only for things that took damage (not walls)

@export var weapon_data: WeaponData
@export var impact_effect_scene: PackedScene = preload("res://scenes/weapons/hit_impact.tscn")

@onready var visual: Node3D = $Visual
@onready var raycast: RayCast3D = $RayCast3D

var current_ammo: int = 12
var reserve_ammo: int = 48
var is_reloading: bool = false
var _fire_timer: float = 0.0
var _reload_sequence_id: int = 0

var _rest_pos: Vector3 = Vector3.ZERO
var _rest_rot: Vector3 = Vector3.ZERO
var _recoil_pos_offset: Vector3 = Vector3.ZERO
var _recoil_rot_offset: Vector3 = Vector3.ZERO

# External node references (injected or resolved in parent hierarchy)
var _camera: Camera3D = null
var _camera_pivot: Node3D = null
var _camera_feedback: CameraFeedbackComponent = null
var _time_manager: Node = null

func _ready() -> void:
	if not weapon_data:
		weapon_data = preload("res://data/pistol_data.tres")
	
	current_ammo = weapon_data.starting_ammo_in_mag
	reserve_ammo = weapon_data.starting_reserve_ammo
	
	_rest_pos = position
	_rest_rot = rotation
	
	_resolve_external_references()
	
	# Initial ammo signal after frame ready
	call_deferred("_emit_initial_ammo")

func _emit_initial_ammo() -> void:
	ammo_changed.emit(current_ammo, reserve_ammo)

func _resolve_external_references() -> void:
	# Locate camera and camera pivot in parent tree
	var curr: Node = get_parent()
	while curr:
		if curr is Camera3D:
			_camera = curr
		if curr.name == "CameraPivot":
			_camera_pivot = curr
		if curr.has_node("Camera3D"):
			_camera = curr.get_node("Camera3D")
		if curr.has_node("CameraFeedbackComponent"):
			_camera_feedback = curr.get_node("CameraFeedbackComponent")
		if not _camera_feedback and _camera and _camera.has_node("CameraFeedbackComponent"):
			_camera_feedback = _camera.get_node("CameraFeedbackComponent")
		curr = curr.get_parent()
	
	if has_node("/root/TimeManager"):
		_time_manager = get_node("/root/TimeManager")

func _process(delta: float) -> void:
	_fire_timer = max(_fire_timer - delta, 0.0)
	
	_handle_input()
	_update_viewmodel_recoil(delta)

func _is_player_dead() -> bool:
	var p = _get_player_ancestor()
	return p != null and "is_dead" in p and p.is_dead

func _handle_input() -> void:
	if _is_player_dead():
		return
	var im = get_node_or_null("/root/InputManager")
	if im and (not im.mouse_captured or im.just_recaptured):
		return
	
	# Fire input (InputMap action only)
	if Input.is_action_just_pressed("fire"):
		try_fire()
	
	# Reload input (InputMap action only)
	if Input.is_action_just_pressed("reload"):
		try_reload()

func try_fire() -> bool:
	if is_reloading:
		return false
	
	if _fire_timer > 0.0:
		return false
	
	if current_ammo <= 0:
		dry_fired.emit()
		# Auto reload if configured and reserve has rounds
		if weapon_data.auto_reload_on_empty and reserve_ammo > 0:
			try_reload()
		return false
	
	# Consume round & reset fire interval
	current_ammo -= 1
	_fire_timer = weapon_data.fire_interval
	ammo_changed.emit(current_ammo, reserve_ammo)
	fired.emit(weapon_data.gunshot_noise_radius)
	var nb = get_node_or_null("/root/NoiseBus")
	if nb:
		nb.emit_noise(global_position, weapon_data.gunshot_noise_radius, _get_player_ancestor(), "gunshot")
	
	# 1. Trigger muzzle flash on visual child
	if visual and visual.has_method("trigger_muzzle_flash"):
		visual.trigger_muzzle_flash()
	
	# 2. Apply camera trauma & FOV kick
	if _camera_feedback:
		_camera_feedback.apply_fire_feedback()
	
	# Determine if last input came from touch
	var im = get_node_or_null("/root/InputManager")
	var is_touch: bool = im.is_last_input_touch() if (im and im.has_method("is_last_input_touch")) else false
	
	# Recoil multiplier: 1.0 for mouse & gamepad, scaled for touch
	var recoil_mult: float = 1.0
	if is_touch:
		recoil_mult = weapon_data.recoil_multiplier_touch
		var sm = get_node_or_null("/root/SettingsManager")
		if sm and "touch_recoil" in sm:
			recoil_mult = sm.touch_recoil
	
	var applied_pitch: float = weapon_data.recoil_pitch * recoil_mult
	var applied_yaw: float = (randf() - 0.5) * 2.0 * weapon_data.recoil_yaw_random * recoil_mult
	
	# 3. Apply camera pitch/yaw kick via player or camera pivot
	var p = _get_player_ancestor()
	if p and p.has_method("apply_camera_recoil"):
		p.apply_camera_recoil(applied_pitch, applied_yaw, is_touch)
	elif _camera_pivot:
		_camera_pivot.rotation.x = clamp(
			_camera_pivot.rotation.x + applied_pitch,
			deg_to_rad(-89.0),
			deg_to_rad(89.0)
		)
		_camera_pivot.rotation.y += applied_yaw
	
	# 4. Apply viewmodel kick
	_recoil_pos_offset += weapon_data.viewmodel_kick_pos * recoil_mult
	_recoil_rot_offset += weapon_data.viewmodel_kick_rot * recoil_mult
	
	# 5. Raycast hit detection
	_perform_hitscan()
	
	return true

func _perform_hitscan() -> void:
	var from_pos: Vector3
	var to_pos: Vector3
	
	if _camera:
		from_pos = _camera.global_position
		to_pos = from_pos - _camera.global_transform.basis.z * weapon_data.max_range
	else:
		from_pos = global_position
		to_pos = from_pos - global_transform.basis.z * weapon_data.max_range
	
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.collision_mask = 1 | 4 | 16 # World (layer 1) + Enemies (layer 3) + Hitboxes (layer 5)
	# Exclude player body from hitscan
	var player_ancestor = _get_player_ancestor()
	if player_ancestor:
		query.exclude = [player_ancestor.get_rid()]
	
	var result: Dictionary = space_state.intersect_ray(query)
	if result:
		var hit_collider: Node = result.collider
		var hit_pos: Vector3 = result.position
		var hit_normal: Vector3 = result.normal
		
		hit_target.emit(hit_collider, hit_pos, hit_normal, weapon_data.damage)
		
		# Spawn visual impact spark
		_spawn_impact(hit_pos, hit_normal)
		
		# Apply damage; the player is passed as the source so the enemy knows where the shot came from
		var target: Node = HealthComponent.find_damageable(hit_collider)
		if target:
			target.take_damage(weapon_data.damage, player_ancestor, "bullet")
			damage_dealt.emit(target, HealthComponent.is_node_dead(target))

			# Gun hit hitstop (0.03s dip)
			if _time_manager and _time_manager.has_method("hitstop"):
				_time_manager.hitstop(weapon_data.hitstop_duration)

func _spawn_impact(pos: Vector3, normal: Vector3) -> void:
	if not impact_effect_scene:
		return
	var impact: Node3D = impact_effect_scene.instantiate() as Node3D
	get_tree().root.add_child(impact)
	impact.global_position = pos + normal * 0.02
	if normal != Vector3.UP and normal != Vector3.DOWN:
		impact.look_at(pos + normal, Vector3.UP)
	impact.reset_physics_interpolation()

func try_reload() -> bool:
	if is_reloading:
		return false
	if current_ammo >= weapon_data.mag_capacity:
		return false
	if reserve_ammo <= 0:
		return false
	
	_start_reload()
	return true

func cancel_reload() -> void:
	if is_reloading:
		_reload_sequence_id += 1
		is_reloading = false
		reload_completed.emit()
	if visual and visual.has_method("hide_muzzle_flash"):
		visual.hide_muzzle_flash()

func _start_reload() -> void:
	if visual and visual.has_method("hide_muzzle_flash"):
		visual.hide_muzzle_flash()
	is_reloading = true
	_reload_sequence_id += 1
	var seq: int = _reload_sequence_id
	reload_started.emit(weapon_data.reload_time)
	
	# Procedural reload motion (tilt viewmodel down during reload)
	_recoil_pos_offset += Vector3(0, -0.08, 0.04)
	_recoil_rot_offset += Vector3(-0.25, 0.15, 0.0)
	
	await get_tree().create_timer(weapon_data.reload_time, true, false, true).timeout
	
	if not is_inside_tree() or seq != _reload_sequence_id or not is_reloading:
		return
	
	var needed: int = weapon_data.mag_capacity - current_ammo
	var to_load: int = min(needed, reserve_ammo)
	current_ammo += to_load
	reserve_ammo -= to_load
	
	is_reloading = false
	ammo_changed.emit(current_ammo, reserve_ammo)
	reload_completed.emit()

func _update_viewmodel_recoil(delta: float) -> void:
	# Lerp recoil offsets back to zero
	_recoil_pos_offset = _recoil_pos_offset.lerp(Vector3.ZERO, weapon_data.viewmodel_recovery_speed * delta)
	_recoil_rot_offset = _recoil_rot_offset.lerp(Vector3.ZERO, weapon_data.viewmodel_recovery_speed * delta)
	
	if _recoil_pos_offset.length_squared() < 0.00001:
		_recoil_pos_offset = Vector3.ZERO
	if _recoil_rot_offset.length_squared() < 0.00001:
		_recoil_rot_offset = Vector3.ZERO
	
	position = _rest_pos + _recoil_pos_offset
	rotation = _rest_rot + _recoil_rot_offset

func _get_player_ancestor() -> CollisionObject3D:
	var curr: Node = get_parent()
	while curr:
		if curr is CollisionObject3D and curr.is_in_group("player"):
			return curr as CollisionObject3D
		curr = curr.get_parent()
	return null

func can_add_reserve_ammo() -> bool:
	return reserve_ammo < weapon_data.max_reserve

## Add ammo to reserve (clamped to max_reserve). Returns actual amount added.
func add_reserve_ammo(amount: int) -> int:
	var space: int = max(weapon_data.max_reserve - reserve_ammo, 0)
	var to_add: int = min(amount, space)
	if to_add > 0:
		reserve_ammo += to_add
		ammo_changed.emit(current_ammo, reserve_ammo)
	return to_add

## Debug / refill helper
func refill_ammo() -> void:
	current_ammo = weapon_data.mag_capacity
	reserve_ammo = weapon_data.max_reserve
	ammo_changed.emit(current_ammo, reserve_ammo)
