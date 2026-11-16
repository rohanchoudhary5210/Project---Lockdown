class_name MeleeController
extends Node3D

## Project: Lockdown - Melee & Defense Controller (Milestone 4 & M4 Review)
## Handles close-quarters melee strikes (35 dmg, 1.8m range, 0.6s cooldown) using ShapeCast3D,
## defensive blocking (-70% damage reduction against MELEE only), and timing-based parrying.
## Parry requires block to be PRESSED within the last 0.25s before the damage frame.
## Holding block or pressing earlier gives normal block (70% reduction).
## Failed parry attempts (block pressed with no incoming hit within 0.25s) trigger a 0.5s lockout.
## Communicates via signals and respects InputMap actions only.

signal attack_swung()
signal attack_hit(target: Node, damage: float)
signal damage_dealt(target: Node, killed: bool) # only for things that took damage (not walls)
signal block_started()
signal block_ended()
signal blocked_attack(damage_mitigated: float)
signal parry_successful(attacker: Node)

@export var melee_data: MeleeData
@export var impact_effect_scene: PackedScene = preload("res://game/scenes/gameplay/weapons/HitImpact.tscn")

@onready var visual: Node3D = $Visual

var is_blocking: bool = false
var block_timer: float = 0.0
var _cooldown_timer: float = 0.0

# Parry timing & anti-spam state
var _parry_lockout_timer: float = 0.0
var _parry_eligible_this_block: bool = false

var _camera: Camera3D = null
var _camera_feedback: CameraFeedbackComponent = null
var _time_manager: Node = null
var _shape_cast: ShapeCast3D = null

func _ready() -> void:
	if not melee_data:
		melee_data = preload("res://game/assets/data/default_melee_data.tres")
	
	_resolve_external_references()
	_setup_shape_cast()

func _resolve_external_references() -> void:
	var curr: Node = get_parent()
	while curr:
		if curr is Camera3D:
			_camera = curr
		if curr.has_node("Camera3D"):
			_camera = curr.get_node("Camera3D")
		if curr.has_node("CameraFeedbackComponent"):
			_camera_feedback = curr.get_node("CameraFeedbackComponent")
		if not _camera_feedback and _camera and _camera.has_node("CameraFeedbackComponent"):
			_camera_feedback = _camera.get_node("CameraFeedbackComponent")
		curr = curr.get_parent()
	
	if has_node("/root/TimeManager"):
		_time_manager = get_node("/root/TimeManager")

func _setup_shape_cast() -> void:
	_shape_cast = ShapeCast3D.new()
	_shape_cast.name = "MeleeShapeCast"
	var sphere := SphereShape3D.new()
	sphere.radius = 0.25 # Forgiving 0.25m sphere sweep for tight corridors
	_shape_cast.shape = sphere
	_shape_cast.target_position = Vector3(0, 0, -melee_data.attack_range)
	_shape_cast.collision_mask = 1 | 4 | 16 # World (layer 1) + Enemies (layer 3) + Hitboxes (layer 5)
	_shape_cast.enabled = false
	var player = _get_player_ancestor()
	if player:
		_shape_cast.add_exception(player)
	add_child(_shape_cast)

func _process(delta: float) -> void:
	_cooldown_timer = max(_cooldown_timer - delta, 0.0)
	_parry_lockout_timer = max(_parry_lockout_timer - delta, 0.0)
	
	if is_blocking:
		block_timer += delta
		# If parry window expires while still holding block without getting hit,
		# parry becomes unavailable and the 0.5s anti-spam lockout begins.
		if _parry_eligible_this_block and block_timer > melee_data.parry_window:
			_parry_eligible_this_block = false
			_parry_lockout_timer = 0.5
	
	_handle_input()

func _handle_input() -> void:
	var player = _get_player_ancestor()
	if player and "is_dead" in player and player.is_dead:
		if is_blocking:
			_end_block()
		return
	
	var im = get_node_or_null("/root/InputManager")
	if im and (not im.mouse_captured or im.just_recaptured):
		if is_blocking:
			_end_block()
		return
	
	# Block handling (InputMap action "block")
	var wants_block: bool = Input.is_action_pressed("block")
	if wants_block:
		if not is_blocking:
			_start_block()
	else:
		if is_blocking:
			_end_block()
	
	# Melee attack handling (InputMap action "melee")
	if Input.is_action_just_pressed("melee") and not is_blocking:
		try_melee_attack()

func _start_block() -> void:
	is_blocking = true
	block_timer = 0.0
	# Eligible for parry only if not under anti-spam lockout
	_parry_eligible_this_block = (_parry_lockout_timer <= 0.0)
	block_started.emit()
	if visual and visual.has_method("set_blocking"):
		visual.set_blocking(true)

func _end_block() -> void:
	# If player releases block during the parry window without getting hit,
	# trigger the 0.5s lockout to prevent rapid button-mashing parry spam
	if _parry_eligible_this_block and block_timer <= melee_data.parry_window:
		_parry_lockout_timer = 0.5
	
	is_blocking = false
	block_timer = 0.0
	_parry_eligible_this_block = false
	block_ended.emit()
	if visual and visual.has_method("set_blocking"):
		visual.set_blocking(false)

func try_melee_attack() -> bool:
	if _cooldown_timer > 0.0:
		return false
	
	_cooldown_timer = melee_data.cooldown
	attack_swung.emit()
	
	if visual and visual.has_method("play_attack_animation"):
		visual.play_attack_animation()
	
	_perform_melee_hit_check()
	return true

func _perform_melee_hit_check() -> void:
	if not _shape_cast:
		_setup_shape_cast()
	
	# Position ShapeCast at camera/eye level and point in view direction
	if _camera:
		_shape_cast.global_transform = _camera.global_transform
	else:
		_shape_cast.global_transform = global_transform
	
	_shape_cast.target_position = Vector3(0, 0, -melee_data.attack_range)
	_shape_cast.force_shapecast_update()
	
	var player = _get_player_ancestor()
	
	if _shape_cast.get_collision_count() > 0:
		# Sweep hit detected! Take the closest valid collision
		var hit_collider: Node = _shape_cast.get_collider(0)
		var hit_pos: Vector3 = _shape_cast.get_collision_point(0)
		var hit_normal: Vector3 = _shape_cast.get_collision_normal(0)
		
		attack_hit.emit(hit_collider, melee_data.damage)
		_spawn_impact(hit_pos, hit_normal)
		
		var damaged: bool = false
		var target: Node = HealthComponent.find_damageable(hit_collider)
		if target:
			target.take_damage(melee_data.damage, player, "melee")
			damage_dealt.emit(target, HealthComponent.is_node_dead(target))
			damaged = true
		
		if damaged and _time_manager and _time_manager.has_method("hitstop"):
			_time_manager.hitstop(melee_data.melee_hitstop)
		
		if _camera_feedback:
			_camera_feedback.apply_melee_hit_feedback()

func _spawn_impact(pos: Vector3, normal: Vector3) -> void:
	if not impact_effect_scene:
		return
	var impact: Node3D = impact_effect_scene.instantiate() as Node3D
	get_tree().root.add_child(impact)
	impact.global_position = pos + normal * 0.02
	if normal != Vector3.UP and normal != Vector3.DOWN:
		impact.look_at(pos + normal, Vector3.UP)
	impact.reset_physics_interpolation()

## Process incoming strike for block / parry defense.
## Block mitigates MELEE damage only, never bullets!
func process_incoming_melee(attacker: Node, raw_damage: float, damage_type: String = "melee") -> Dictionary:
	# Rule: Block reduces MELEE damage only, never bullets
	if damage_type != "melee":
		return {
			"result": "hit",
			"damage_dealt": raw_damage,
			"attacker_stunned": false,
			"stun_duration": 0.0
		}
	
	if is_blocking:
		if _parry_eligible_this_block and block_timer <= melee_data.parry_window:
			# SUCCESSFUL PARRY (Pressed within 0.25s before damage frame: 100% negation + 1.5s stun)
			_parry_eligible_this_block = false
			if attacker and attacker.has_method("apply_stun"):
				attacker.apply_stun(melee_data.parry_stun_duration)
			
			if _time_manager and _time_manager.has_method("hitstop"):
				_time_manager.hitstop(melee_data.parry_hitstop)
			
			parry_successful.emit(attacker)
			return {
				"result": "parry",
				"damage_dealt": 0.0,
				"attacker_stunned": true,
				"stun_duration": melee_data.parry_stun_duration
			}
		else:
			# REGULAR BLOCK (-70% damage reduction for holding or pressed earlier)
			var mitigated: float = raw_damage * melee_data.block_damage_reduction
			var damage_dealt: float = raw_damage - mitigated
			
			if _time_manager and _time_manager.has_method("hitstop"):
				_time_manager.hitstop(0.04)
			
			blocked_attack.emit(mitigated)
			return {
				"result": "blocked",
				"damage_dealt": damage_dealt,
				"attacker_stunned": false,
				"stun_duration": 0.0
			}
	
	# UNBLOCKED HIT (100% damage)
	return {
		"result": "hit",
		"damage_dealt": raw_damage,
		"attacker_stunned": false,
		"stun_duration": 0.0
	}

func _get_player_ancestor() -> CollisionObject3D:
	var curr: Node = get_parent()
	while curr:
		if curr is CollisionObject3D and curr.is_in_group("player"):
			return curr as CollisionObject3D
		curr = curr.get_parent()
	return null
