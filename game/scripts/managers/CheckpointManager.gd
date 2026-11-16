class_name CheckpointManager
extends Node

## Project: Lockdown - Checkpoint & Respawn Manager (Milestone 6)
## Coordinates checkpoint snapshots, encounter zone rollbacks, player death sequences,
## death screen presentation, and 1.5s post-respawn invulnerability.

signal checkpoint_activated(checkpoint_name: String)
signal player_death_started()
signal death_screen_shown()
signal player_respawned()
signal invulnerability_changed(is_invulnerable: bool)

class CheckpointSnapshot:
	var player_position: Vector3
	var player_rotation_y: float
	var player_camera_pitch: float
	var health: float
	var mag_ammo: int
	var reserve_ammo: int
	var checkpoint_name: String
	var checkpoint_order: int = -1
	var captive_states: Dictionary = {}

var current_snapshot: CheckpointSnapshot = null
var level_start_snapshot: CheckpointSnapshot = null
var active_checkpoint_node: Node = null
var current_checkpoint_order: int = -1

var is_dying: bool = false
var is_respawning: bool = false
var _invulnerability_timer: float = 0.0

var _game: GameManager
var _bus: Node
## Services come from GameService (see GameService._inject_into_new_nodes); null when run without it.
var _input_manager: InputManager
var _time_manager: TimeManager

func inject_services(registry: Node) -> void:
	_game = registry.get_service(&"game") as GameManager
	_bus = registry.get_service(&"bus")
	_input_manager = registry.get_service(&"input") as InputManager
	_time_manager = registry.get_service(&"time") as TimeManager

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_setup_initial_session")

func _process(delta: float) -> void:
	if _invulnerability_timer > 0.0:
		_invulnerability_timer = maxf(0.0, _invulnerability_timer - delta)
		if _invulnerability_timer <= 0.0:
			_set_player_invulnerable(false)

func _setup_initial_session() -> void:
	var player: Player = _get_player()
	if player:
		_connect_player(player)
		_capture_level_start_snapshot(player)

## Called when a player is spawned or when a scene reloads to register the new player instance
func register_player(player: Player) -> void:
	if not player:
		return
	_connect_player(player)
	_capture_level_start_snapshot(player)
	is_dying = false
	is_respawning = false

## Resets the entire checkpoint session (e.g. when restarting a floor or loading a new level)
func reset_session() -> void:
	current_snapshot = null
	active_checkpoint_node = null
	current_checkpoint_order = -1
	is_dying = false
	is_respawning = false
	_invulnerability_timer = 0.0
	var player: Player = _get_player()
	if player:
		_connect_player(player)
		_capture_level_start_snapshot(player)

func _connect_player(player: Player) -> void:
	if not player.player_died.is_connected(_on_player_died):
		player.player_died.connect(_on_player_died)

func _get_player() -> Player:
	return get_tree().get_first_node_in_group("player") as Player

func _capture_level_start_snapshot(player: Player) -> void:
	level_start_snapshot = CheckpointSnapshot.new()
	level_start_snapshot.player_position = player.global_position
	level_start_snapshot.player_rotation_y = player.rotation.y
	level_start_snapshot.player_camera_pitch = player._pitch if "_pitch" in player else 0.0
	level_start_snapshot.health = player.health_component.max_health if player.health_component else 100.0
	
	var weapon: WeaponController = player.find_child("Pistol", true, false) as WeaponController
	if weapon and weapon.weapon_data:
		level_start_snapshot.mag_ammo = weapon.weapon_data.starting_ammo_in_mag
		level_start_snapshot.reserve_ammo = weapon.weapon_data.starting_reserve_ammo
	else:
		level_start_snapshot.mag_ammo = 12
		level_start_snapshot.reserve_ammo = 48
	
	level_start_snapshot.checkpoint_name = "Level Start"
	level_start_snapshot.checkpoint_order = -1
	
	var captives = get_tree().get_nodes_in_group("captives")
	for c in captives:
		level_start_snapshot.captive_states[c.captive_id] = c.is_rescued

## Records a checkpoint snapshot when player steps on a Checkpoint node
func record_checkpoint(checkpoint: Node, player_node: Node) -> void:
	var order: int = checkpoint.checkpoint_order if "checkpoint_order" in checkpoint else 0
	if order <= current_checkpoint_order:
		return
	
	if active_checkpoint_node and active_checkpoint_node != checkpoint:
		if active_checkpoint_node.has_method("deactivate"):
			active_checkpoint_node.deactivate()
	
	active_checkpoint_node = checkpoint
	current_checkpoint_order = order
	
	var player = player_node
	if not player:
		player = _get_player()
	
	current_snapshot = CheckpointSnapshot.new()
	current_snapshot.checkpoint_order = order
	current_snapshot.checkpoint_name = checkpoint.name
	
	if player and (player is Node3D):
		current_snapshot.player_position = player.global_position
		current_snapshot.player_rotation_y = player.rotation.y
		current_snapshot.player_camera_pitch = player._pitch if "_pitch" in player else 0.0
		if "health_component" in player and player.health_component:
			current_snapshot.health = player.health_component.current_health
		else:
			current_snapshot.health = 100.0
		
		var weapon: WeaponController = player.find_child("Pistol", true, false) as WeaponController
		if weapon:
			current_snapshot.mag_ammo = weapon.current_ammo
			current_snapshot.reserve_ammo = weapon.reserve_ammo
		else:
			current_snapshot.mag_ammo = 12
			current_snapshot.reserve_ammo = 48
	
	# Record captive states at this checkpoint
	var captives = get_tree().get_nodes_in_group("captives")
	for c in captives:
		current_snapshot.captive_states[c.captive_id] = c.is_rescued
	
	# Commit all encounter zones to this checkpoint
	var zones = get_tree().get_nodes_in_group("encounter_zones")
	for z in zones:
		if z.has_method("commit_checkpoint"):
			z.commit_checkpoint()
	
	checkpoint_activated.emit(current_snapshot.checkpoint_name)

func _on_player_died() -> void:
	if is_dying or is_respawning:
		return
	
	handle_player_death()

## Initiates death sequence: slow-mo + fade to dark (~1s), then death screen
func handle_player_death() -> void:
	is_dying = true
	player_death_started.emit()
	if _game:
		_game.game_over("player_died")
	if _bus:
		_bus.player_died.emit()
	
	# Abort any active hitstop or pause
	var tm = _time_manager
	if tm and tm.has_method("reset_time_scale"):
		tm.reset_time_scale()
	if get_tree().paused:
		get_tree().paused = false
	
	# Slow-motion time dilation (~0.25x)
	Engine.time_scale = 0.25
	
	# Wait for 1.0 real second (using real untracked time)
	var timer = get_tree().create_timer(1.0, true, false, true)
	await timer.timeout
	
	# Death sequence ends: Engine.time_scale must be 1.0!
	if tm and tm.has_method("reset_time_scale"):
		tm.reset_time_scale()
	Engine.time_scale = 1.0
	
	# Enable Death Screen and release mouse
	var im = _input_manager
	if im:
		im.is_death_screen_active = true
		im.mouse_captured = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	death_screen_shown.emit()

## Restores player and environment from the latest snapshot
func respawn_player() -> void:
	var snap: CheckpointSnapshot = current_snapshot if current_snapshot else level_start_snapshot
	var player: Player = _get_player()
	
	if snap:
		current_checkpoint_order = snap.checkpoint_order
	
	# Abort hitstop and ensure time scale 1.0
	var tm = _time_manager
	if tm and tm.has_method("reset_time_scale"):
		tm.reset_time_scale()
	Engine.time_scale = 1.0
	if get_tree().paused:
		get_tree().paused = false
	
	if player and snap:
		# 1. Reset Stance & State
		player.is_dead = false
		player.is_crouching = false
		player.is_sprinting = false
		if player.player_data:
			player.current_camera_height = player.player_data.stand_camera_height
			player.target_camera_height = player.player_data.stand_camera_height
			player._update_collision_shape(player.player_data.stand_height)
		
		# 2. Restore Transform & Teleport (resets physics interpolation on player and top_level camera_pivot)
		if player.has_method("teleport"):
			player.teleport(snap.player_position, snap.player_rotation_y, snap.player_camera_pitch)
		else:
			player.global_position = snap.player_position
			player.rotation.y = snap.player_rotation_y
			player.velocity = Vector3.ZERO
			player.reset_physics_interpolation()
			if "_pitch" in player:
				player._pitch = snap.player_camera_pitch
			if player.camera_pivot:
				player.camera_pivot.global_position = player.global_position + Vector3(0.0, player.current_camera_height, 0.0)
				player.camera_pivot.global_transform.basis = Basis.from_euler(Vector3(player._pitch, player.rotation.y, 0.0))
				player.camera_pivot.reset_physics_interpolation()
		
		if player.camera:
			player.camera.position = Vector3.ZERO
			player.camera.rotation = Vector3.ZERO
			player.camera.reset_physics_interpolation()
		
		# 3. Restore Health (Minimum 50 HP)
		var respawn_hp = maxf(snap.health, 50.0)
		if player.player_data:
			respawn_hp = minf(respawn_hp, player.player_data.max_health)
		if player.health_component:
			player.health_component.reset_health()
			player.health_component.current_health = respawn_hp
			player.health_component.health_changed.emit(respawn_hp, player.health_component.max_health)
		
		# 4. Restore Ammo & Cancel any in-progress reload
		var weapon: WeaponController = player.find_child("Pistol", true, false) as WeaponController
		if weapon:
			weapon.cancel_reload()
			weapon.current_ammo = snap.mag_ammo
			weapon.reserve_ammo = snap.reserve_ammo
			weapon.ammo_changed.emit(weapon.current_ammo, weapon.reserve_ammo)
		
		# 5. Apply 1.5s Invulnerability
		_set_player_invulnerable(true)
		_invulnerability_timer = 1.5
	
	# 6. Restore Encounter Zones (revert enemies & pickups altered after checkpoint)
	var zones = get_tree().get_nodes_in_group("encounter_zones")
	for z in zones:
		if z.has_method("reset_to_checkpoint"):
			z.reset_to_checkpoint()
	
	# 7. Restore Captive Teammates (revert rescue if performed after checkpoint)
	if snap and "captive_states" in snap:
		var captives = get_tree().get_nodes_in_group("captives")
		for c in captives:
			var was_rescued = snap.captive_states.get(c.captive_id, false)
			if c.has_method("set_rescued_state"):
				c.set_rescued_state(was_rescued)
	
	# 8. Recapture mouse & re-enable input
	var im = _input_manager
	if im:
		im.is_death_screen_active = false
		im.capture_mouse()
	
	is_dying = false
	is_respawning = false
	if _game:
		_game.reset() # back to PLAYING (also from PAUSED when restarting via the pause menu)
		_game.start()
	if _bus:
		_bus.player_respawned.emit()
	player_respawned.emit()

func _set_player_invulnerable(invuln: bool) -> void:
	var player = _get_player()
	if player and player.health_component:
		player.health_component.invulnerable = invuln
	invulnerability_changed.emit(invuln)
