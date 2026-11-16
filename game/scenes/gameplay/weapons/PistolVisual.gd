class_name PistolVisual
extends Node3D

## Project: Lockdown - Pistol Viewmodel Visual
## Handles visual presentation, procedural muzzle flash, and slide blowback.

@onready var muzzle_flash_light: OmniLight3D = $MuzzleFlash/FlashLight
@onready var muzzle_flash_mesh: MeshInstance3D = $MuzzleFlash/FlashMesh
@onready var slide: Node3D = $Slide

var _initial_slide_z: float = 0.0
var _flash_timer: float = 0.0

## Services come from GameService (see GameService._inject_into_new_nodes); null when run without it.
var _checkpoints: CheckpointManager
var _input_manager: InputManager

func inject_services(registry: Node) -> void:
	_checkpoints = registry.get_service(&"checkpoint") as CheckpointManager
	_input_manager = registry.get_service(&"input") as InputManager

func _ready() -> void:
	hide_muzzle_flash()
	if slide:
		_initial_slide_z = slide.position.z
	
	var im = _input_manager
	if im and im.has_signal("pause_toggled"):
		im.pause_toggled.connect(_on_pause_toggled)
	
	var cm = _checkpoints
	if cm and cm.has_signal("player_respawned"):
		cm.player_respawned.connect(_on_player_respawned)

func _process(delta: float) -> void:
	if _flash_timer > 0.0:
		_flash_timer -= delta
		if _flash_timer <= 0.0:
			hide_muzzle_flash()

func trigger_muzzle_flash(duration: float = 0.04) -> void:
	_flash_timer = duration
	if muzzle_flash_light:
		muzzle_flash_light.visible = true
	if muzzle_flash_mesh:
		muzzle_flash_mesh.visible = true
		muzzle_flash_mesh.rotation.z = randf() * TAU
	
	# Slide blowback kick
	if slide:
		slide.position.z = _initial_slide_z + 0.04

func hide_muzzle_flash() -> void:
	_flash_timer = 0.0
	if muzzle_flash_light:
		muzzle_flash_light.visible = false
	if muzzle_flash_mesh:
		muzzle_flash_mesh.visible = false
	if slide:
		slide.position.z = _initial_slide_z

func _on_pause_toggled(is_paused: bool) -> void:
	if is_paused:
		hide_muzzle_flash()

func _on_player_respawned() -> void:
	hide_muzzle_flash()
