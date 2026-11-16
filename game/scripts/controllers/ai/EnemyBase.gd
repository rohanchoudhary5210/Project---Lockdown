class_name EnemyBase
extends CharacterBody3D

## Project: Lockdown - Base Enemy Character & State Machine
## Implements core AI state model (IDLE, PATROL, INVESTIGATE, SEARCH, CHASE, ATTACK, STUNNED, DEAD),
## pathfinding via NavigationAgent3D, perception integration, acoustic alerts via NoiseBus,
## and last-known-player-position tracking with ~8s search timeout.

signal state_changed(old_state: State, new_state: State)
signal enemy_died(enemy: EnemyBase)

enum State {
	IDLE,
	PATROL,
	INVESTIGATE,
	SEARCH,
	CHASE,
	ATTACK,
	STUNNED,
	DEAD
}

@export var enemy_data: EnemyData
@export var patrol_points: Array[Vector3] = []

@onready var health_component: HealthComponent = $HealthComponent
@onready var perception: EnemyPerception = $EnemyPerception
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

var current_state: State = State.IDLE
var last_known_player_position: Vector3 = Vector3.ZERO
var search_timer: float = 0.0
var stun_timer: float = 0.0
var patrol_index: int = 0
var gravity: float = 19.6
var was_alerted_by_peer: bool = false
var alert_source_name: String = ""

var _search_turn_timer: float = 0.0
var _search_target_yaw: float = 0.0
var _step_distance_counter: float = 0.0
var _death_tween: Tween = null
const STEP_DISTANCE: float = 2.2

func _ready() -> void:
	if not is_in_group("enemies"):
		add_to_group("enemies")
	
	if not enemy_data:
		enemy_data = preload("res://game/assets/data/ranged_enemy_data.tres")
	
	if health_component:
		health_component.max_health = enemy_data.max_health
		health_component.current_health = enemy_data.max_health
		health_component.died.connect(_on_health_depleted)
	
	if perception:
		perception.enemy_data = enemy_data
		perception.player_spotted.connect(_on_player_spotted)
		perception.player_lost.connect(_on_player_lost)
		perception.noise_heard.connect(_on_noise_heard)
	
	# Fallback patrol point if none configured
	if patrol_points.is_empty():
		patrol_points.append(global_position)
	
	call_deferred("_setup_navigation")

func _setup_navigation() -> void:
	if nav_agent:
		nav_agent.path_desired_distance = 0.8
		nav_agent.target_desired_distance = 1.0

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return
	
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	
	match current_state:
		State.IDLE:
			_tick_idle(delta)
		State.PATROL:
			_tick_patrol(delta)
		State.INVESTIGATE:
			_tick_investigate(delta)
		State.SEARCH:
			_tick_search(delta)
		State.CHASE:
			_tick_chase(delta)
		State.ATTACK:
			_tick_attack(delta)
		State.STUNNED:
			_tick_stunned(delta)
	
	move_and_slide()
	
	if is_on_floor() and (current_state in [State.PATROL, State.INVESTIGATE, State.CHASE]):
		var horiz_speed: float = Vector2(velocity.x, velocity.z).length()
		if horiz_speed > 0.5:
			_step_distance_counter += horiz_speed * delta
			if _step_distance_counter >= STEP_DISTANCE:
				_step_distance_counter = 0.0
				var am = get_node_or_null("/root/SpatialAudio")
				if am and am.has_method("play_footstep_3d"):
					am.play_footstep_3d(global_position)

func change_state(new_state: State) -> void:
	if current_state == new_state or current_state == State.DEAD:
		return
	
	var old = current_state
	current_state = new_state
	
	# State Enter Handlers
	match new_state:
		State.PATROL:
			_update_patrol_destination()
		State.INVESTIGATE:
			if nav_agent:
				nav_agent.target_position = last_known_player_position
		State.SEARCH:
			search_timer = enemy_data.search_duration
			_search_turn_timer = 0.0
			velocity.x = 0.0
			velocity.z = 0.0
		State.CHASE:
			was_alerted_by_peer = false
			if nav_agent:
				nav_agent.target_position = last_known_player_position
			_share_alert_with_nearby_enemies()
		State.STUNNED:
			velocity.x = 0.0
			velocity.z = 0.0
		State.DEAD:
			velocity = Vector3.ZERO
			collision_layer = 0
			collision_mask = 0
			_play_death_fall()
			enemy_died.emit(self)
	
	if new_state not in [State.INVESTIGATE, State.SEARCH]:
		was_alerted_by_peer = false
	
	state_changed.emit(old, new_state)

## Receives an alert broadcast from a nearby peer that spotted the player
func receive_shared_alert(player_pos: Vector3, alerter: EnemyBase) -> void:
	if current_state in [State.IDLE, State.PATROL, State.SEARCH]:
		last_known_player_position = player_pos
		was_alerted_by_peer = true
		if alerter:
			alert_source_name = alerter.name
		change_state(State.INVESTIGATE)

## Broadcasts player's last known position to nearby enemies (within 10m with LOS)
func _share_alert_with_nearby_enemies() -> void:
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if e == self or not is_instance_valid(e) or not (e is EnemyBase):
			continue
		if e.current_state in [State.DEAD, State.STUNNED, State.CHASE, State.ATTACK]:
			continue
		
		var dist = global_position.distance_to(e.global_position)
		if dist <= 10.0:
			if _has_los_to_enemy(e):
				e.receive_shared_alert(last_known_player_position, self)

func get_chest_position() -> Vector3:
	return global_position + Vector3(0, 1.1, 0)

func is_alive() -> bool:
	if current_state == State.DEAD:
		return false
	if health_component and health_component.current_health <= 0:
		return false
	return true

func _has_los_to_enemy(other: EnemyBase) -> bool:
	var from_pos = global_position + Vector3(0, 1.5, 0)
	var to_pos = other.global_position + Vector3(0, 1.5, 0)
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.collision_mask = 1 # Only world obstacles block LOS between enemies
	query.exclude = [get_rid(), other.get_rid()]
	var res = space_state.intersect_ray(query)
	return res.is_empty()

func _tick_idle(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
	if patrol_points.size() > 0:
		change_state(State.PATROL)

func _tick_patrol(delta: float) -> void:
	if patrol_points.is_empty():
		change_state(State.IDLE)
		return
	
	if nav_agent.is_navigation_finished():
		patrol_index = (patrol_index + 1) % patrol_points.size()
		_update_patrol_destination()
		return
	
	_move_along_nav_path(enemy_data.move_speed_patrol, delta)

func _update_patrol_destination() -> void:
	if not patrol_points.is_empty() and nav_agent:
		nav_agent.target_position = patrol_points[patrol_index]

func _tick_investigate(delta: float) -> void:
	if nav_agent.is_navigation_finished() or global_position.distance_to(last_known_player_position) < 1.2:
		# Arrived at suspicious sound location; initiate search
		change_state(State.SEARCH)
		return
	
	_move_along_nav_path(enemy_data.move_speed_patrol * 1.2, delta)

func _tick_search(delta: float) -> void:
	search_timer -= delta
	if search_timer <= 0.0:
		# Search expired (~8s); return to patrol
		change_state(State.PATROL)
		return
	
	# Periodically turn to scan surroundings while searching
	_search_turn_timer -= delta
	if _search_turn_timer <= 0.0:
		_search_turn_timer = randf_range(1.5, 2.5)
		_search_target_yaw = rotation.y + randf_range(-PI * 0.75, PI * 0.75)
	
	rotation.y = lerp_angle(rotation.y, _search_target_yaw, 3.0 * delta)
	velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)

func _tick_chase(delta: float) -> void:
	# If perception has active line of sight, continuously update last known position
	if perception and perception.has_line_of_sight and perception.player_ref:
		last_known_player_position = perception.player_ref.global_position
		if nav_agent:
			nav_agent.target_position = last_known_player_position
	
	# Check subclass-specific attack transitions
	if _can_attack():
		change_state(State.ATTACK)
		return
	
	if nav_agent.is_navigation_finished() or global_position.distance_to(last_known_player_position) < 1.2:
		if not (perception and perception.has_line_of_sight):
			# Lost player; search the area
			change_state(State.SEARCH)
			return
	
	_move_along_nav_path(enemy_data.move_speed_chase, delta)

func _tick_attack(delta: float) -> void:
	# Virtual method implemented by Ranged / Rusher subclasses
	pass

func _can_attack() -> bool:
	# Virtual method implemented by Ranged / Rusher subclasses
	return false

func _tick_stunned(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
	stun_timer -= delta
	if stun_timer <= 0.0:
		if perception and perception.has_line_of_sight:
			change_state(State.CHASE)
		else:
			change_state(State.SEARCH)

func _move_along_nav_path(speed: float, delta: float) -> void:
	var next_pos: Vector3 = nav_agent.get_next_path_position()
	var dir: Vector3 = (next_pos - global_position)
	dir.y = 0.0
	
	if dir.length_squared() > 0.01:
		dir = dir.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
		
		# Rotate smoothly toward movement direction
		var target_angle: float = atan2(-dir.x, -dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 8.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)

func _on_player_spotted(spotted_pos: Vector3) -> void:
	last_known_player_position = spotted_pos
	if current_state != State.DEAD and current_state != State.STUNNED:
		change_state(State.CHASE)

func _on_player_lost(last_pos: Vector3) -> void:
	last_known_player_position = last_pos
	if current_state == State.ATTACK:
		change_state(State.CHASE)

func _on_noise_heard(noise_pos: Vector3, _radius: float, _source: Node) -> void:
	if current_state in [State.IDLE, State.PATROL, State.SEARCH]:
		last_known_player_position = noise_pos
		change_state(State.INVESTIGATE)

func apply_stun(duration: float = 1.5) -> void:
	if current_state == State.DEAD:
		return
	stun_timer = duration
	change_state(State.STUNNED)

func take_damage(amount: float, source: Node = null, damage_type: String = "bullet") -> void:
	if current_state == State.DEAD:
		return
	
	var final_damage = amount
	if damage_type == "bullet" and enemy_data:
		final_damage *= enemy_data.bullet_damage_multiplier
	
	if health_component:
		health_component.take_damage(final_damage, source)
	
	# Taking damage alerts the enemy to the attacker's location
	if source and is_instance_valid(source) and current_state != State.DEAD and current_state != State.STUNNED:
		last_known_player_position = source.global_position
		if current_state in [State.IDLE, State.PATROL, State.SEARCH, State.INVESTIGATE]:
			change_state(State.CHASE)

func _on_health_depleted() -> void:
	change_state(State.DEAD)

## Tips the body over backwards around the feet (origin), lifted so the capsule rests on the floor.
func _play_death_fall() -> void:
	if _death_tween:
		_death_tween.kill()
	_death_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel(true)
	_death_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_death_tween.tween_property(self, "rotation:x", PI * 0.5, 0.45)
	_death_tween.tween_property(self, "position:y", position.y + 0.3, 0.45)

func reset_to_spawn(spawn_transform: Transform3D) -> void:
	if _death_tween:
		_death_tween.kill()
		_death_tween = null
	global_transform = spawn_transform
	reset_physics_interpolation()
	velocity = Vector3.ZERO
	collision_layer = 4 # Enemies layer
	collision_mask = 7 # World (1) + Player (2) + Enemies (4)
	
	if health_component:
		health_component.reset_health()
	
	current_state = State.PATROL
	patrol_index = 0
	last_known_player_position = Vector3.ZERO
	was_alerted_by_peer = false
	search_timer = 0.0
	stun_timer = 0.0
	
	if perception:
		perception.reset_perception()
	
	call_deferred("_setup_navigation")
	_update_patrol_destination()

func get_state_name() -> String:
	match current_state:
		State.IDLE: return "IDLE"
		State.PATROL: return "PATROL"
		State.INVESTIGATE: return "INVESTIGATE"
		State.SEARCH: return "SEARCH"
		State.CHASE: return "CHASE"
		State.ATTACK: return "ATTACK"
		State.STUNNED: return "STUNNED"
		State.DEAD: return "DEAD"
	return "UNKNOWN"
