class_name Player
extends CharacterBody3D

## Project: Lockdown - Player Controller
## Handles first-person movement, stance changes, jumping, gravity, look,
## health management, and interactions.
## Adheres strictly to InputMap actions; does not read raw keys/mouse/touch.

signal stance_changed(is_crouching: bool)
signal sprint_changed(is_sprinting: bool)
signal moved(velocity: Vector3, is_grounded: bool)
signal footstep_emitted(noise_radius: float)
signal interaction_prompt_changed(prompt_text: String)
signal rescue_progress_changed(progress: float)
signal player_died()

@export var player_data: PlayerData
@export var aim_assist_data: AimAssistData

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var ceiling_check: RayCast3D = $CeilingCheck
@onready var visual: Node3D = $PlayerVisual
@onready var weapon_mount: Node3D = $CameraPivot/WeaponMount
@onready var interaction_ray: RayCast3D = $CameraPivot/InteractionRay
@onready var health_component: HealthComponent = $HealthComponent
@onready var camera_feedback: CameraFeedbackComponent = $CameraPivot/Camera3D/CameraFeedbackComponent
@onready var melee_controller: MeleeController = $CameraPivot/WeaponMount/MeleeWeapon

var is_crouching: bool = false
var is_sprinting: bool = false
var is_dead: bool = false
var current_camera_height: float = 1.6
var target_camera_height: float = 1.6

var _pitch: float = 0.0
var _step_distance_counter: float = 0.0
var _input_manager: Node = null
var _last_prompt: String = ""
var _active_hold_target: Node = null
var _hold_interact_timer: float = 0.0
var _touch_recoil_recovery_pitch: float = 0.0
var _touch_recoil_recovery_speed: float = 0.0
var _touch_recoil_recovery_yaw: float = 0.0
var _touch_recoil_recovery_yaw_speed: float = 0.0
var _camera_recoil_yaw: float = 0.0
var _last_process_frame: int = -1
const STEP_DISTANCE: float = 2.2

var aim_assist_setting: String = "Off"
var current_aim_target: EnemyBase = null
var current_aim_target_angle_deg: float = 0.0
var current_aim_target_dist: float = 0.0
var _aim_debug_overlay: Node = null
var _just_teleported: bool = true

var _logger: Node
## Services come from GameService (see GameService._inject_into_new_nodes); null when run without it.
var _checkpoints: CheckpointManager
var _noise_bus: NoiseBus
var _settings: SettingsManager
var _spatial_audio: SpatialAudioManager

func inject_services(registry: Node) -> void:
	_logger = registry.get_service(&"logger")
	_checkpoints = registry.get_service(&"checkpoint") as CheckpointManager
	_input_manager = registry.get_service(&"input") as InputManager
	_noise_bus = registry.get_service(&"noise") as NoiseBus
	_settings = registry.get_service(&"settings") as SettingsManager
	_spatial_audio = registry.get_service(&"spatial_audio") as SpatialAudioManager

func _ready() -> void:
	if not player_data:
		player_data = preload("res://game/assets/data/default_player_data.tres")
	if not aim_assist_data:
		aim_assist_data = preload("res://game/assets/data/default_aim_assist_data.tres")
	
	if OS.is_debug_build() and not _aim_debug_overlay:
		var overlay_script = load("res://game/scripts/controllers/player/AimAssistDebugOverlay.gd")
		if overlay_script:
			_aim_debug_overlay = Node3D.new()
			_aim_debug_overlay.name = "AimAssistDebugOverlay"
			_aim_debug_overlay.set_script(overlay_script)
			add_child(_aim_debug_overlay)
	
	current_camera_height = player_data.stand_camera_height
	target_camera_height = player_data.stand_camera_height
	if camera_pivot:
		camera_pivot.top_level = true
		camera_pivot.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		camera_pivot.global_position = global_position + Vector3(0.0, current_camera_height, 0.0)
		_apply_camera_orientation()
		camera_pivot.reset_physics_interpolation()
	if camera:
		camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		camera.fov = player_data.default_fov
		camera.reset_physics_interpolation()
	reset_physics_interpolation()
	
	_update_collision_shape(player_data.stand_height)
	
	var im: Node = _get_input_manager()
	if im and im.has_method("configure_from_player_data"):
		im.configure_from_player_data(player_data)
	
	if health_component:
		health_component.max_health = player_data.max_health
		health_component.current_health = player_data.max_health
		health_component.damaged.connect(_on_damaged)
		health_component.died.connect(_on_died)
	
	var cm = _checkpoints
	if cm and cm.has_method("register_player"):
		cm.register_player(self)
	
	var sm = _settings
	if sm and sm.has_method("apply_to_player"):
		sm.apply_to_player(self)
	
	var am = _spatial_audio
	if am and am.has_method("register_player"):
		am.register_player(self)
	
	# Haptics: light tap on each shot, strong one on a parry (taking damage is in _on_damaged)
	var pistol = weapon_mount.find_child("Pistol", true, false) if weapon_mount else null
	if pistol and pistol.has_signal("fired"):
		pistol.fired.connect(func(_r): _vibrate(15, 0.3))
	if melee_controller:
		melee_controller.parry_successful.connect(func(_a): _vibrate(60, 1.0))

func _get_input_manager() -> Node:
	if not _input_manager and is_inside_tree():
		_input_manager = _input_manager
	return _input_manager

## Synchronizes top_level camera_pivot world orientation with pitch, player body yaw and recoil yaw
func _apply_camera_orientation() -> void:
	if camera_pivot:
		camera_pivot.global_transform.basis = Basis.from_euler(Vector3(_pitch, global_rotation.y + _camera_recoil_yaw, 0.0))

func _process(delta: float) -> void:
	if not is_inside_tree():
		return
	
	if not is_dead:
		var im: Node = _get_input_manager()
		if not im or im.mouse_captured:
			_handle_look(delta)
	
	# Smooth stance height transition in process for high refresh rates
	current_camera_height = lerp(
		current_camera_height,
		target_camera_height,
		player_data.stance_transition_speed * delta
	)
	
	if camera_pivot:
		var cam_base_pos: Vector3 = global_position if _just_teleported else get_global_transform_interpolated().origin
		camera_pivot.global_position = cam_base_pos + Vector3(0.0, current_camera_height, 0.0)
		_apply_camera_orientation()

func _recover_touch_recoil(delta: float) -> void:
	if _touch_recoil_recovery_pitch > 0.0001:
		var recover_pitch = minf(_touch_recoil_recovery_pitch, _touch_recoil_recovery_speed * delta)
		_touch_recoil_recovery_pitch -= recover_pitch
		_pitch = clamp(_pitch - recover_pitch, deg_to_rad(-89.0), deg_to_rad(89.0))
	
	if absf(_touch_recoil_recovery_yaw) > 0.0001:
		var recover_yaw = signf(_touch_recoil_recovery_yaw) * minf(absf(_touch_recoil_recovery_yaw), absf(_touch_recoil_recovery_yaw_speed) * delta)
		_touch_recoil_recovery_yaw -= recover_yaw
		_camera_recoil_yaw -= recover_yaw
	
	_apply_camera_orientation()

func _physics_process(delta: float) -> void:
	_just_teleported = false
	if is_dead:
		if not is_on_floor():
			velocity.y -= player_data.gravity * delta
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	
	var im: Node = _get_input_manager()
	if im and not im.mouse_captured:
		if not is_on_floor():
			velocity.y -= player_data.gravity * delta
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	
	_recover_touch_recoil(delta)
	_handle_stance(delta)
	_handle_movement(delta)
	_handle_footsteps(delta)
	_handle_interaction(delta)
	
	move_and_slide()
	moved.emit(velocity, is_on_floor())

func _handle_look(delta: float) -> void:
	var im: Node = _get_input_manager()
	var look_delta: Vector2 = Vector2.ZERO
	if im and im.has_method("get_look_delta"):
		look_delta = im.get_look_delta(delta)
	else:
		var action_look: Vector2 = Input.get_vector("look_left", "look_right", "look_up", "look_down")
		look_delta = action_look * player_data.controller_look_speed * delta
		if player_data.invert_y:
			look_delta.y = -look_delta.y
	
	# Apply Aim Assist (friction and magnetism for touch/gamepad)
	look_delta = _update_aim_assist(delta, look_delta)
	
	if look_delta == Vector2.ZERO:
		return
	
	# Horizontal rotation (yaw) rotates the body
	rotate_y(-look_delta.x)
	
	# Vertical rotation (pitch) rotates the camera pivot, clamped to prevent flip
	_pitch = clamp(_pitch - look_delta.y, deg_to_rad(-89.0), deg_to_rad(89.0))
	_apply_camera_orientation()

func _update_aim_assist(delta: float, look_delta: Vector2) -> Vector2:
	current_aim_target = null
	current_aim_target_angle_deg = 0.0
	current_aim_target_dist = 0.0
	
	if not aim_assist_data or not camera:
		return look_delta
	
	# Aim assist disabled while dead, paused, or in death screen
	if is_dead:
		return look_delta
	
	var im: Node = _get_input_manager()
	if im:
		if im.is_gameplay_paused or im.is_death_screen_active or im.is_level_clear_active:
			return look_delta
		# Mouse never gets aim assist, even if the setting is on
		if im.last_input_device == im.InputDevice.MOUSE_KEYBOARD:
			return look_delta
	
	if aim_assist_setting == "Off":
		return look_delta
	
	var enemies = get_tree().get_nodes_in_group("enemies")
	if enemies.is_empty():
		return look_delta
	
	var cam_pos: Vector3 = camera.global_position
	var cam_forward: Vector3 = -camera.global_transform.basis.z
	var space_state = get_world_3d().direct_space_state
	
	var best_target: EnemyBase = null
	var best_angle_rad: float = INF
	var best_chest_pos: Vector3 = Vector3.ZERO
	var best_dist: float = 0.0
	
	for node in enemies:
		if not is_instance_valid(node) or not (node is EnemyBase):
			continue
		var enemy: EnemyBase = node as EnemyBase
		if not enemy.is_alive():
			continue
		
		var chest_pos: Vector3 = enemy.get_chest_position()
		var to_chest: Vector3 = chest_pos - cam_pos
		var dist: float = to_chest.length()
		if dist > aim_assist_data.max_range: # Within 25m only
			continue
		
		var dir_to_chest: Vector3 = to_chest / dist
		# Must be in front of player
		if cam_forward.dot(dir_to_chest) <= 0.0:
			continue
		
		var angle_rad: float = cam_forward.angle_to(dir_to_chest)
		var angle_deg: float = rad_to_deg(angle_rad)
		if angle_deg > aim_assist_data.assist_cone_angle_deg:
			continue
		
		# Line of sight check (world-layer raycast, collision_mask = 1 only)
		var query = PhysicsRayQueryParameters3D.create(cam_pos, chest_pos)
		query.collision_mask = 1 # World layer only, never through walls
		query.exclude = [get_rid(), enemy.get_rid()]
		query.collide_with_areas = false
		query.collide_with_bodies = true
		var hit = space_state.intersect_ray(query)
		if not hit.is_empty():
			# Occluded by world wall / obstacle
			continue
		
		# Only one target at a time: the one closest to the crosshair, not closest in distance
		if angle_rad < best_angle_rad:
			best_angle_rad = angle_rad
			best_target = enemy
			best_chest_pos = chest_pos
			best_dist = dist
	
	if not best_target:
		return look_delta
	
	current_aim_target = best_target
	current_aim_target_angle_deg = rad_to_deg(best_angle_rad)
	current_aim_target_dist = best_dist
	
	# Friction: while crosshair is within ~4° of enemy chest, look speed is reduced (Low 0.75x, High 0.55x)
	if current_aim_target_angle_deg <= aim_assist_data.friction_angle_deg:
		var friction_scale: float = aim_assist_data.friction_scale_high if aim_assist_setting == "High" else aim_assist_data.friction_scale_low
		look_delta *= friction_scale
	
	# Magnetism: only while moving look OR firing, gently rotate camera toward nearest valid target chest (Low 2°/s, High 5°/s max)
	var is_moving_look: bool = look_delta.length_squared() > 0.000001
	var is_firing: bool = Input.is_action_pressed("fire")
	if is_moving_look or is_firing:
		var max_speed_deg: float = aim_assist_data.magnetism_speed_high_deg if aim_assist_setting == "High" else aim_assist_data.magnetism_speed_low_deg
		var max_step_rad: float = deg_to_rad(max_speed_deg) * delta
		
		var target_dir: Vector3 = (best_chest_pos - cam_pos).normalized()
		var cam_basis: Basis = camera.global_transform.basis
		var local_dir: Vector3 = cam_basis.inverse() * target_dir
		
		var yaw_error: float = atan2(local_dir.x, -local_dir.z)
		var pitch_error: float = atan2(local_dir.y, -local_dir.z)
		var total_error: float = sqrt(yaw_error * yaw_error + pitch_error * pitch_error)
		
		if total_error > 0.0001:
			var step: float = minf(total_error, max_step_rad)
			var step_yaw: float = (yaw_error / total_error) * step
			var step_pitch: float = (pitch_error / total_error) * step
			
			rotate_y(-step_yaw)
			_pitch = clamp(_pitch + step_pitch, deg_to_rad(-89.0), deg_to_rad(89.0))
			_apply_camera_orientation()
	
	return look_delta

func _handle_stance(delta: float) -> void:
	var wants_crouch: bool = false
	if player_data.crouch_toggle_mode:
		if Input.is_action_just_pressed("crouch"):
			wants_crouch = not is_crouching
		else:
			wants_crouch = is_crouching
	else:
		wants_crouch = Input.is_action_pressed("crouch")
	
	if wants_crouch:
		if not is_crouching:
			is_crouching = true
			target_camera_height = player_data.crouch_camera_height
			_update_collision_shape(player_data.crouch_height)
			stance_changed.emit(true)
	else:
		if is_crouching:
			var can_stand: bool = true
			if ceiling_check and ceiling_check.is_colliding():
				can_stand = false
			
			if can_stand:
				is_crouching = false
				target_camera_height = player_data.stand_camera_height
				_update_collision_shape(player_data.stand_height)
				stance_changed.emit(false)

func _update_collision_shape(height: float) -> void:
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var capsule: CapsuleShape3D = collision_shape.shape
		capsule.height = height
		collision_shape.position.y = height * 0.5

func _handle_movement(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= player_data.gravity * delta
	else:
		# Jumping
		if Input.is_action_just_pressed("jump") and not is_crouching:
			velocity.y = player_data.jump_velocity
	
	# Movement direction via InputMap actions
	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var input_len: float = clampf(input_vector.length(), 0.0, 1.0)
	var move_direction: Vector3 = Vector3.ZERO
	if input_len > 0.0001:
		move_direction = (transform.basis * Vector3(input_vector.x, 0, input_vector.y)) / input_len
	
	# Determine speed based on stance & sprint
	var wants_sprint: bool = Input.is_action_pressed("sprint") and not is_crouching and input_vector.y < -0.1
	if wants_sprint != is_sprinting:
		is_sprinting = wants_sprint
		sprint_changed.emit(is_sprinting)
	
	var base_speed: float = player_data.walk_speed
	if is_crouching:
		base_speed = player_data.crouch_speed
	elif is_sprinting:
		base_speed = player_data.sprint_speed
	
	var target_speed: float = base_speed * input_len
	
	# Horizontal velocity interpolation
	var target_velocity_h: Vector3 = move_direction * target_speed
	var current_velocity_h: Vector3 = Vector3(velocity.x, 0, velocity.z)
	
	var accel: float
	if is_on_floor():
		accel = player_data.acceleration if move_direction != Vector3.ZERO else player_data.deceleration
	else:
		accel = player_data.acceleration * player_data.air_control
	
	current_velocity_h = current_velocity_h.move_toward(target_velocity_h, accel * delta)
	velocity.x = current_velocity_h.x
	velocity.z = current_velocity_h.z

func _handle_footsteps(delta: float) -> void:
	if not is_on_floor():
		return
	
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	if horizontal_speed < 0.2:
		return
	
	_step_distance_counter += horizontal_speed * delta
	if _step_distance_counter >= STEP_DISTANCE:
		_step_distance_counter = 0.0
		var noise_radius: float = player_data.noise_walk
		if is_crouching:
			noise_radius = player_data.noise_crouch
		elif is_sprinting:
			noise_radius = player_data.noise_sprint
		
		footstep_emitted.emit(noise_radius)
		var nb = _noise_bus
		if nb:
			nb.emit_noise(global_position, noise_radius, self, "footstep")

func _handle_interaction(delta: float) -> void:
	var prompt: String = ""
	var target: Node = null
	
	if interaction_ray and interaction_ray.is_colliding():
		var col: Node = interaction_ray.get_collider()
		if col:
			if col.has_method("get_prompt"):
				prompt = col.get_prompt()
				target = col
			elif col.has_node("InteractableComponent"):
				var ic: InteractableComponent = col.get_node("InteractableComponent") as InteractableComponent
				prompt = ic.get_prompt()
				target = ic
			elif col.has_method("interact"):
				prompt = "[E] Interact"
				target = col
	
	if prompt != _last_prompt:
		_last_prompt = prompt
		interaction_prompt_changed.emit(_last_prompt)
	
	# Check for Hold-to-Interact target (e.g. Captive Officer rescue)
	var is_hold: bool = false
	var hold_target: Node = null
	if target:
		if target.get("is_hold_interaction") == true or target.has_method("complete_interaction"):
			is_hold = true
			hold_target = target
		elif target is InteractableComponent and target.get_parent() and target.get_parent().get("is_hold_interaction") == true:
			is_hold = true
			hold_target = target.get_parent()
	
	if is_hold and hold_target and not hold_target.get("is_rescued"):
		_active_hold_target = hold_target
		
		# Cancel if player moved away (> 2.2m)
		var dist: float = global_position.distance_to(hold_target.global_position)
		if dist > 2.2:
			_cancel_hold_interaction()
			return
		
		if Input.is_action_pressed("interact"):
			var duration: float = hold_target.hold_duration if "hold_duration" in hold_target else 2.0
			_hold_interact_timer += delta
			var progress: float = clampf(_hold_interact_timer / duration, 0.0, 1.0)
			rescue_progress_changed.emit(progress)
			
			if _hold_interact_timer >= duration:
				if hold_target.has_method("complete_interaction"):
					hold_target.complete_interaction(self)
				elif hold_target.has_method("interact"):
					hold_target.interact(self)
				_cancel_hold_interaction()
		else:
			if _hold_interact_timer > 0.0:
				_cancel_hold_interaction()
	else:
		if _hold_interact_timer > 0.0:
			_cancel_hold_interaction()
		
		# Instant interaction fallback (AmmoStash, Medkit, etc.)
		if target and Input.is_action_just_pressed("interact"):
			if target is InteractableComponent:
				target.interact(self)
			elif target.has_method("interact"):
				target.interact(self)

func _cancel_hold_interaction() -> void:
	_hold_interact_timer = 0.0
	_active_hold_target = null
	rescue_progress_changed.emit(0.0)

## Damage interface - checks melee defense/parry then forwards to HealthComponent.
## Block mitigates MELEE damage only, never bullets!
func take_damage(amount: float, source: Node = null, damage_type: String = "melee") -> void:
	var damage_to_take: float = amount
	if melee_controller and melee_controller.is_blocking:
		var defense: Dictionary = melee_controller.process_incoming_melee(source, amount, damage_type)
		damage_to_take = defense.damage_dealt
		if defense.result == "parry":
			return # Fully negated by timed parry!
	
	if health_component and damage_to_take > 0.0:
		health_component.take_damage(damage_to_take, source)

func heal(amount: float) -> void:
	if health_component:
		health_component.heal(amount)

func _vibrate(duration_ms: int, strength: float) -> void:
	var sm = _settings
	if sm and sm.has_method("vibrate"):
		sm.vibrate(duration_ms, strength)

func _on_damaged(_amount: float, _source: Node) -> void:
	_cancel_hold_interaction()
	_vibrate(40, 0.6)
	if camera_feedback:
		camera_feedback.apply_damage_taken_feedback()

func apply_camera_recoil(pitch_kick: float, yaw_kick: float, is_touch: bool = false) -> void:
	_pitch = clamp(_pitch + pitch_kick, deg_to_rad(-89.0), deg_to_rad(89.0))
	_camera_recoil_yaw += yaw_kick
	_apply_camera_orientation()
	
	if is_touch:
		_touch_recoil_recovery_pitch += pitch_kick
		_touch_recoil_recovery_speed = _touch_recoil_recovery_pitch / 0.25
		_touch_recoil_recovery_yaw += yaw_kick
		_touch_recoil_recovery_yaw_speed = _touch_recoil_recovery_yaw / 0.25

## Teleports player to target position, updating camera pivot and clearing interpolation history
func teleport(target_pos: Vector3, target_yaw: float = -999.0, target_pitch: float = -999.0) -> void:
	global_position = target_pos
	velocity = Vector3.ZERO
	_just_teleported = true
	if target_yaw != -999.0:
		rotation.y = target_yaw
	if target_pitch != -999.0:
		_pitch = clamp(target_pitch, deg_to_rad(-89.0), deg_to_rad(89.0))
	_touch_recoil_recovery_pitch = 0.0
	_touch_recoil_recovery_yaw = 0.0
	_camera_recoil_yaw = 0.0
	
	if camera_pivot:
		camera_pivot.global_position = global_position + Vector3(0.0, current_camera_height, 0.0)
		_apply_camera_orientation()
		camera_pivot.reset_physics_interpolation()
	
	if camera:
		camera.position = Vector3.ZERO
		camera.rotation = Vector3.ZERO
		camera.reset_physics_interpolation()
	
	reset_physics_interpolation()

func _on_died() -> void:
	is_dead = true
	_touch_recoil_recovery_pitch = 0.0
	_touch_recoil_recovery_yaw = 0.0
	_camera_recoil_yaw = 0.0
	_apply_camera_orientation()
	if _logger:
		_logger.info("Player died, input frozen until respawn")
	player_died.emit()

func get_current_noise_radius() -> float:
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	if not is_on_floor() or horizontal_speed < 0.2:
		return 0.0
	if is_crouching:
		return player_data.noise_crouch
	if is_sprinting:
		return player_data.noise_sprint
	return player_data.noise_walk
