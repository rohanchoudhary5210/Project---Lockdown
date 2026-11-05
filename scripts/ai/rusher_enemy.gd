class_name RusherEnemy
extends EnemyBase

## Project: Lockdown - Rusher Enemy Archetype (Milestone 5b)
## Aggressive close-quarters melee combatant.
## 100 HP, 20m vision, 5.5 m/s chase speed, 20 melee damage, 0.4s telegraph, 1.6m reach.
## 0.8s attack recovery window (punish window).
## Flinch: Bullet hits interrupt movement for 0.15s and cancel active telegraphs.
## Stun: Parrying stuns for 1.5s; melee attacks against a stunned Rusher deal 1.5x damage.

signal attack_started()
signal attack_finished()
signal flinched()

@onready var telegraph_component: EnemyMeleeTelegraphComponent = $EnemyMeleeTelegraphComponent
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var _recovery_timer: float = 0.0
var _flinch_timer: float = 0.0
var _flinch_cooldown_timer: float = 0.0

var _normal_mat: StandardMaterial3D = null
var _telegraph_mat: StandardMaterial3D = null
var _stun_mat: StandardMaterial3D = null

func _ready() -> void:
	if not enemy_data:
		enemy_data = preload("res://data/rusher_enemy_data.tres")
	
	super._ready()
	_setup_materials()
	
	if telegraph_component:
		telegraph_component.attack_damage = enemy_data.melee_damage
		telegraph_component.telegraph_duration = enemy_data.telegraph_duration
		telegraph_component.attack_telegraphed.connect(_on_attack_telegraphed)
		telegraph_component.attack_executed.connect(_on_attack_executed)
		telegraph_component.attack_cancelled.connect(_on_attack_cancelled)
		telegraph_component.stunned.connect(_on_telegraph_stunned)
		telegraph_component.stun_recovered.connect(_on_telegraph_stun_recovered)

func _setup_materials() -> void:
	if mesh_instance and mesh_instance.get_active_material(0):
		_normal_mat = mesh_instance.get_active_material(0).duplicate()
		
		_telegraph_mat = _normal_mat.duplicate()
		_telegraph_mat.albedo_color = Color(1.0, 0.6, 0.1) # Amber telegraph
		_telegraph_mat.emission_enabled = true
		_telegraph_mat.emission = Color(0.9, 0.45, 0.0)
		
		_stun_mat = _normal_mat.duplicate()
		_stun_mat.albedo_color = Color(0.2, 0.65, 1.0) # Electric blue stunned
		_stun_mat.emission_enabled = true
		_stun_mat.emission = Color(0.1, 0.45, 0.95)

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return
	
	# Flinch cooldown timer (Rusher can flinch at most once every 0.6s)
	if _flinch_cooldown_timer > 0.0:
		_flinch_cooldown_timer = maxf(0.0, _flinch_cooldown_timer - delta)
	
	# Attack recovery timer (0.8s punish window)
	_recovery_timer = maxf(0.0, _recovery_timer - delta)
	
	# Flinch timer: interrupts movement for 0.15s on bullet hit
	if _flinch_timer > 0.0:
		_flinch_timer = maxf(0.0, _flinch_timer - delta)
		velocity.x = move_toward(velocity.x, 0.0, 25.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 25.0 * delta)
		if not is_on_floor():
			velocity.y -= gravity * delta
		move_and_slide()
		return
	
	super._physics_process(delta)

func _can_attack() -> bool:
	if _recovery_timer > 0.0 or _flinch_timer > 0.0:
		return false
	if current_state == State.STUNNED or current_state == State.DEAD:
		return false
	if not perception or not perception.player_ref or not perception.has_line_of_sight:
		return false
	
	var dist = global_position.distance_to(perception.player_ref.global_position)
	return dist <= enemy_data.attack_range

func _tick_attack(delta: float) -> void:
	if not perception or not perception.player_ref:
		change_state(State.CHASE)
		return
	
	var player = perception.player_ref
	
	# Rotate to face player during attack
	var to_player = (player.global_position - global_position)
	to_player.y = 0.0
	if to_player.length_squared() > 0.01:
		var target_angle = atan2(-to_player.normalized().x, -to_player.normalized().z)
		rotation.y = lerp_angle(rotation.y, target_angle, 12.0 * delta)
	
	# Halt movement during attack wind-up
	velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
	
	if telegraph_component:
		if not telegraph_component.is_telegraphing and _recovery_timer <= 0.0:
			telegraph_component.trigger_telegraphed_attack(player)

func _on_attack_telegraphed() -> void:
	attack_started.emit()
	if mesh_instance and _telegraph_mat:
		mesh_instance.set_surface_override_material(0, _telegraph_mat)

func _on_attack_executed() -> void:
	# Enter 0.8s recovery punish window after attack
	_recovery_timer = enemy_data.attack_recovery_time
	if mesh_instance:
		mesh_instance.set_surface_override_material(0, null)
	attack_finished.emit()
	change_state(State.CHASE)

func _on_attack_cancelled() -> void:
	if mesh_instance and current_state != State.STUNNED:
		mesh_instance.set_surface_override_material(0, null)
	if current_state == State.ATTACK:
		change_state(State.CHASE)

func _on_telegraph_stunned(duration: float) -> void:
	stun_timer = duration
	change_state(State.STUNNED)
	if mesh_instance and _stun_mat:
		mesh_instance.set_surface_override_material(0, _stun_mat)

func _on_telegraph_stun_recovered() -> void:
	if mesh_instance:
		mesh_instance.set_surface_override_material(0, null)
	if current_state == State.STUNNED:
		if perception and perception.has_line_of_sight:
			change_state(State.CHASE)
		else:
			change_state(State.SEARCH)

func reset_to_spawn(spawn_transform: Transform3D) -> void:
	_recovery_timer = 0.0
	_flinch_timer = 0.0
	_flinch_cooldown_timer = 0.0
	if mesh_instance:
		mesh_instance.set_surface_override_material(0, null)
	if telegraph_component:
		if telegraph_component.is_telegraphing:
			telegraph_component.cancel_telegraph()
		telegraph_component.is_stunned = false
	super.reset_to_spawn(spawn_transform)

func apply_stun(duration: float = 1.5) -> void:
	if telegraph_component:
		telegraph_component.apply_stun(duration)
	else:
		super.apply_stun(duration)

func take_damage(amount: float, source: Node = null, damage_type: String = "bullet") -> void:
	var final_damage = amount
	
	# Melee hits on a stunned Rusher deal 1.5x damage!
	if current_state == State.STUNNED and damage_type == "melee":
		final_damage *= enemy_data.stun_vulnerability_multiplier
	
	# Bullet hits flinch the Rusher (at most once every 0.6s)
	if damage_type == "bullet" and current_state != State.DEAD:
		if _flinch_cooldown_timer <= 0.0:
			_flinch_cooldown_timer = enemy_data.flinch_cooldown if enemy_data else 0.6
			_flinch_timer = enemy_data.flinch_duration if enemy_data else 0.15
			if telegraph_component and telegraph_component.is_telegraphing:
				telegraph_component.cancel_telegraph()
			flinched.emit()
	
	super.take_damage(final_damage, source, damage_type)
