extends Node

## Project: Lockdown - Audio Manager Autoload
## Manages SFX pools, 3D positional audio, building ambience, low-HP heartbeat,
## and wires game events to synthesized procedural audio resources.

const BUS_MASTER := "Master"
const BUS_SFX := "SFX"
const BUS_AMBIENCE := "Ambience"

const POOL_SIZE_2D := 12
const POOL_SIZE_3D := 8

# Preloaded Procedural Audio Resources
var sfx_pistol_shot: AudioStreamWAV = preload("res://assets/procedural/audio/sfx_pistol_shot.tres")
var sfx_rifle_shot: AudioStreamWAV = preload("res://assets/procedural/audio/sfx_rifle_shot.tres")
var sfx_dry_fire: AudioStreamWAV = preload("res://assets/procedural/audio/sfx_dry_fire.tres")
var sfx_reload: AudioStreamWAV = preload("res://assets/procedural/audio/sfx_reload.tres")
var sfx_melee_swing: AudioStreamWAV = preload("res://assets/procedural/audio/sfx_melee_swing.tres")
var sfx_melee_hit: AudioStreamWAV = preload("res://assets/procedural/audio/sfx_melee_hit.tres")
var sfx_parry_clang: AudioStreamWAV = preload("res://assets/procedural/audio/sfx_parry_clang.tres")
var sfx_block_thud: AudioStreamWAV = preload("res://assets/procedural/audio/sfx_block_thud.tres")
var sfx_footsteps: Array[AudioStreamWAV] = [
	preload("res://assets/procedural/audio/sfx_footstep_1.tres"),
	preload("res://assets/procedural/audio/sfx_footstep_2.tres"),
	preload("res://assets/procedural/audio/sfx_footstep_3.tres"),
	preload("res://assets/procedural/audio/sfx_footstep_4.tres")
]
var sfx_pickup: AudioStreamWAV = preload("res://assets/procedural/audio/sfx_pickup.tres")
var sfx_checkpoint_chime: AudioStreamWAV = preload("res://assets/procedural/audio/sfx_checkpoint_chime.tres")
var sfx_heartbeat: AudioStreamWAV = preload("res://assets/procedural/audio/sfx_heartbeat.tres")
var amb_building_hum: AudioStreamWAV = preload("res://assets/procedural/audio/amb_building_hum.tres")

# Players
var _players_2d: Array[AudioStreamPlayer] = []
var _player_2d_index: int = 0

var _players_3d: Array[AudioStreamPlayer3D] = []
var _player_3d_index: int = 0

var _ambience_player: AudioStreamPlayer = null

# Heartbeat & player state tracking
var _player_ref: Node = null
var _heartbeat_timer: float = 0.0
const HEARTBEAT_INTERVAL: float = 0.8
const LOW_HP_THRESHOLD: float = 30.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_audio_buses()
	_create_player_pools()
	_create_ambience_player()
	
	# Connect to CheckpointManager if available
	var cm = get_node_or_null("/root/CheckpointManager")
	if cm and cm.has_signal("checkpoint_activated"):
		cm.checkpoint_activated.connect(_on_checkpoint_activated)
	
	start_ambience()

func _process(delta: float) -> void:
	_tick_heartbeat(delta)

func _setup_audio_buses() -> void:
	# Ensure SFX and Ambience buses exist
	if AudioServer.get_bus_index(BUS_SFX) == -1:
		AudioServer.add_bus()
		var idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, BUS_SFX)
		AudioServer.set_bus_send(idx, BUS_MASTER)
	
	if AudioServer.get_bus_index(BUS_AMBIENCE) == -1:
		AudioServer.add_bus()
		var idx = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(idx, BUS_AMBIENCE)
		AudioServer.set_bus_send(idx, BUS_MASTER)
		AudioServer.set_bus_volume_db(idx, -4.0)

func _create_player_pools() -> void:
	# 2D SFX pool
	for i in range(POOL_SIZE_2D):
		var p = AudioStreamPlayer.new()
		p.bus = BUS_SFX
		p.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p)
		_players_2d.append(p)
	
	# 3D SFX pool
	for i in range(POOL_SIZE_3D):
		var p3 = AudioStreamPlayer3D.new()
		p3.bus = BUS_SFX
		p3.max_distance = 40.0
		p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p3.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(p3)
		_players_3d.append(p3)

func _create_ambience_player() -> void:
	_ambience_player = AudioStreamPlayer.new()
	_ambience_player.bus = BUS_AMBIENCE
	_ambience_player.stream = amb_building_hum
	_ambience_player.volume_db = -2.0
	_ambience_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ambience_player)

func start_ambience() -> void:
	if _ambience_player and not _ambience_player.playing:
		_ambience_player.play()

func stop_ambience() -> void:
	if _ambience_player and _ambience_player.playing:
		_ambience_player.stop()

# --- Playback API ---

func play_sfx(stream: AudioStream, pitch_variation: float = 0.05, volume_db: float = 0.0) -> AudioStreamPlayer:
	if not stream or _players_2d.is_empty():
		return null
	
	var player = _players_2d[_player_2d_index]
	_player_2d_index = (_player_2d_index + 1) % POOL_SIZE_2D
	
	player.stream = stream
	player.volume_db = volume_db
	if pitch_variation > 0.0:
		player.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	else:
		player.pitch_scale = 1.0
	player.play()
	return player

func play_sfx_3d(stream: AudioStream, global_pos: Vector3, pitch_variation: float = 0.05, volume_db: float = 0.0, max_dist: float = 40.0) -> AudioStreamPlayer3D:
	if not stream or _players_3d.is_empty():
		return null
	
	var player = _players_3d[_player_3d_index]
	_player_3d_index = (_player_3d_index + 1) % POOL_SIZE_3D
	
	player.global_position = global_pos
	player.reset_physics_interpolation()
	player.max_distance = max_dist
	player.stream = stream
	player.volume_db = volume_db
	if pitch_variation > 0.0:
		player.pitch_scale = randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	else:
		player.pitch_scale = 1.0
	player.play()
	return player

# --- Convenience Event Methods ---

func play_pistol_shot() -> void:
	play_sfx(sfx_pistol_shot, 0.05, -1.0)

func play_rifle_shot(pos: Vector3) -> void:
	play_sfx_3d(sfx_rifle_shot, pos, 0.06, 2.0, 50.0)

func play_dry_fire() -> void:
	play_sfx(sfx_dry_fire, 0.04, -3.0)

func play_reload() -> void:
	play_sfx(sfx_reload, 0.03, -2.0)

func play_melee_swing() -> void:
	play_sfx(sfx_melee_swing, 0.05, -2.0)

func play_melee_hit() -> void:
	play_sfx(sfx_melee_hit, 0.05, 1.0)

func play_parry() -> void:
	play_sfx(sfx_parry_clang, 0.03, 2.0)

func play_block() -> void:
	play_sfx(sfx_block_thud, 0.05, 0.0)

func play_footstep(is_player: bool = true) -> void:
	if sfx_footsteps.is_empty():
		return
	var step_stream = sfx_footsteps[randi() % sfx_footsteps.size()]
	play_sfx(step_stream, 0.05, -6.0 if is_player else -4.0)

func play_footstep_3d(pos: Vector3) -> void:
	if sfx_footsteps.is_empty():
		return
	var step_stream = sfx_footsteps[randi() % sfx_footsteps.size()]
	play_sfx_3d(step_stream, pos, 0.05, -4.0, 25.0)

func play_pickup() -> void:
	play_sfx(sfx_pickup, 0.02, 0.0)

func play_checkpoint() -> void:
	play_sfx(sfx_checkpoint_chime, 0.0, 2.0)

# --- Automatic Player Hooking ---

func register_player(player: Node) -> void:
	_player_ref = player
	
	if player.has_signal("footstep_emitted"):
		if not player.footstep_emitted.is_connected(_on_player_footstep):
			player.footstep_emitted.connect(_on_player_footstep)
	
	# Hook WeaponController
	var weapon = player.find_child("Pistol", true, false)
	if weapon:
		if weapon.has_signal("fired") and not weapon.fired.is_connected(_on_weapon_fired):
			weapon.fired.connect(_on_weapon_fired)
		if weapon.has_signal("dry_fired") and not weapon.dry_fired.is_connected(play_dry_fire):
			weapon.dry_fired.connect(play_dry_fire)
		if weapon.has_signal("reload_started") and not weapon.reload_started.is_connected(_on_reload_started):
			weapon.reload_started.connect(_on_reload_started)
	
	# Hook MeleeController
	var melee = player.find_child("MeleeWeapon", true, false)
	if melee:
		if melee.has_signal("attack_swung") and not melee.attack_swung.is_connected(play_melee_swing):
			melee.attack_swung.connect(play_melee_swing)
		if melee.has_signal("attack_hit") and not melee.attack_hit.is_connected(_on_melee_hit):
			melee.attack_hit.connect(_on_melee_hit)
		if melee.has_signal("blocked_attack") and not melee.blocked_attack.is_connected(_on_block):
			melee.blocked_attack.connect(_on_block)
		if melee.has_signal("parry_successful") and not melee.parry_successful.is_connected(_on_parry):
			melee.parry_successful.connect(_on_parry)

func _on_player_footstep(noise_radius: float) -> void:
	if noise_radius > 0.0:
		play_footstep(true)

func _on_weapon_fired(_radius: float) -> void:
	play_pistol_shot()

func _on_reload_started(_dur: float) -> void:
	play_reload()

func _on_melee_hit(_target: Node, _dmg: float) -> void:
	play_melee_hit()

func _on_block(_mitigated: float) -> void:
	play_block()

func _on_parry(_attacker: Node) -> void:
	play_parry()

func _on_checkpoint_activated(_name: String) -> void:
	play_checkpoint()

# --- Low-HP Heartbeat Loop ---

func _tick_heartbeat(delta: float) -> void:
	if not is_instance_valid(_player_ref):
		# Attempt to find player in current tree
		var p = get_tree().get_first_node_in_group("player")
		if p:
			register_player(p)
		return
	
	var health_comp = _player_ref.get_node_or_null("HealthComponent")
	if not health_comp:
		return
	
	var current_hp = health_comp.current_health
	if current_hp > 0.0 and current_hp <= LOW_HP_THRESHOLD:
		_heartbeat_timer += delta
		if _heartbeat_timer >= HEARTBEAT_INTERVAL:
			_heartbeat_timer = 0.0
			play_sfx(sfx_heartbeat, 0.03, 1.0)
	else:
		_heartbeat_timer = 0.0
