class_name PauseMenu
extends UIController

## Project: Lockdown - Pause Menu (Milestone 9)
## Options: Resume, Settings, Restart from Checkpoint, Quit to Main Menu.
## A UIManager panel: the HUD pushes it when the game pauses and pops it on resume.
## Works with tree pause (process_mode ALWAYS, set in the scene).

const SETTINGS_SCENE: PackedScene = preload("res://game/scenes/ui/mfw/SettingsMenu.tscn")
const HOME_SCENE: String = "res://game/scenes/Home/Home.tscn"

signal resumed()
signal settings_opened()
signal restart_checkpoint_requested()
signal quit_requested()

@onready var menu_panel: Control = %MenuPanel
@onready var resume_button: Button = %ResumeButton
@onready var settings_button: Button = %SettingsButton
@onready var restart_button: Button = %RestartButton
@onready var quit_button: Button = %QuitButton

## Services come from GameService (see GameService._inject_into_new_nodes); null when run without it.
var _checkpoints: CheckpointManager
var _input_manager: InputManager
var _scene: SceneManager

func inject_services(registry: Node) -> void:
	super.inject_services(registry)
	_checkpoints = registry.get_service(&"checkpoint") as CheckpointManager
	_input_manager = registry.get_service(&"input") as InputManager
	_scene = registry.get_service(&"scene") as SceneManager

func _on_ready() -> void:
	resume_button.pressed.connect(_on_resume_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	restart_button.pressed.connect(_on_restart_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	visibility_changed.connect(_on_visibility_changed)
	resume_button.grab_focus()

## Back from the settings panel (UIManager shows this one again).
func _on_visibility_changed() -> void:
	if visible and is_inside_tree():
		settings_button.grab_focus()

func _on_resume_pressed() -> void:
	resumed.emit()
	var im = _input_manager
	if im and im.has_method("capture_mouse"):
		im.capture_mouse() # unpauses; the HUD closes this panel on pause_toggled(false)

func _on_settings_pressed() -> void:
	_ui_manager.push_packed(SETTINGS_SCENE)
	var settings := _ui_manager.current() as SettingsMenu
	settings.refresh_values()
	settings.focus_first()
	settings_opened.emit()

func _on_restart_pressed() -> void:
	restart_checkpoint_requested.emit()
	var cm = _checkpoints
	if cm and cm.has_method("respawn_player"):
		cm.respawn_player() # unpauses and recaptures the mouse -> the HUD closes this panel

func _on_quit_pressed() -> void:
	quit_requested.emit()
	var im = _input_manager
	if im:
		im.is_gameplay_paused = false
		im.mouse_captured = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	_ui_manager.pop_to_root()
	_ui_manager.pop()
	_scene.go_to(HOME_SCENE)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause"):
		_on_resume_pressed()
		get_viewport().set_input_as_handled()
