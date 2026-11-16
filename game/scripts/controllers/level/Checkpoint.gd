class_name Checkpoint
extends Area3D

## Project: Lockdown - Checkpoint Node (Milestone 6)
## Trigger volume that activates on player touch.
## Stores a snapshot via CheckpointManager and updates its visual lamp.

signal activated(checkpoint: Checkpoint)

@export var checkpoint_id: String = ""
@export var checkpoint_order: int = 0 ## Progression order; higher = later
@export var is_start_checkpoint: bool = false

@onready var indicator_mesh: MeshInstance3D = $Visual/Lamp
@onready var lamp_light: OmniLight3D = $Visual/LampLight

var is_active: bool = false
var _unactive_mat: StandardMaterial3D = null
var _active_mat: StandardMaterial3D = null
var _player_inside: bool = false
var _player_inside_ref: Node3D = null

## Services come from GameService (see GameService._inject_into_new_nodes); null when run without it.
var _checkpoints: CheckpointManager

func inject_services(registry: Node) -> void:
	_checkpoints = registry.get_service(&"checkpoint") as CheckpointManager

func _ready() -> void:
	if checkpoint_id.is_empty():
		checkpoint_id = name
	
	collision_layer = 0
	collision_mask = 2 # Detects Player on layer 2
	
	_setup_materials()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	if _player_inside and not is_active and is_instance_valid(_player_inside_ref):
		var cm = _checkpoints
		if cm and "current_checkpoint_order" in cm:
			if checkpoint_order <= cm.current_checkpoint_order:
				return
		if not _is_combat_active():
			activate(_player_inside_ref)

func _is_combat_active() -> bool:
	var enemies = get_tree().get_nodes_in_group("enemies")
	for e in enemies:
		if is_instance_valid(e) and (e is EnemyBase):
			if e.current_state in [EnemyBase.State.CHASE, EnemyBase.State.ATTACK]:
				return true
	return false

func _setup_materials() -> void:
	_unactive_mat = StandardMaterial3D.new()
	_unactive_mat.albedo_color = Color(0.4, 0.35, 0.1)
	_unactive_mat.emission_enabled = true
	_unactive_mat.emission = Color(0.6, 0.35, 0.05)
	_unactive_mat.emission_energy_multiplier = 0.5
	
	_active_mat = StandardMaterial3D.new()
	_active_mat.albedo_color = Color(0.1, 0.85, 0.5)
	_active_mat.emission_enabled = true
	_active_mat.emission = Color(0.1, 0.95, 0.55)
	_active_mat.emission_energy_multiplier = 2.0
	
	_update_visuals()

func _update_visuals() -> void:
	if indicator_mesh:
		indicator_mesh.material_override = _active_mat if is_active else _unactive_mat
	if lamp_light:
		lamp_light.visible = is_active
		lamp_light.light_color = Color(0.2, 1.0, 0.6)

func _on_body_entered(body: Node3D) -> void:
	if is_active:
		return
	
	var cm = _checkpoints
	if cm and "current_checkpoint_order" in cm:
		if checkpoint_order <= cm.current_checkpoint_order:
			return
	
	if body.is_in_group("player"):
		_player_inside = true
		_player_inside_ref = body
		if not _is_combat_active():
			activate(body)

func _on_body_exited(body: Node3D) -> void:
	if body == _player_inside_ref:
		_player_inside = false
		_player_inside_ref = null

func activate(player: Node3D) -> void:
	if is_active:
		return
	
	var cm = _checkpoints
	if cm and "current_checkpoint_order" in cm:
		if checkpoint_order <= cm.current_checkpoint_order:
			return
	
	is_active = true
	_update_visuals()
	activated.emit(self)
	
	if cm and cm.has_method("record_checkpoint"):
		cm.record_checkpoint(self, player)

func deactivate() -> void:
	is_active = false
	_update_visuals()
