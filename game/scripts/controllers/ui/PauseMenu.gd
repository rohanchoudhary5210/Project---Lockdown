class_name PauseMenu
extends Control

## Project: Lockdown - Pause Menu (Milestone 9)
## Options: Resume, Settings, Restart from Checkpoint, Quit to Main Menu.
## Works with tree pause (PROCESS_MODE_ALWAYS).

signal resumed()
signal settings_opened()
signal restart_checkpoint_requested()
signal quit_requested()

@onready var menu_panel: Control = %MenuPanel
@onready var resume_button: Button = %ResumeButton
@onready var settings_button: Button = %SettingsButton
@onready var restart_button: Button = %RestartButton
@onready var quit_button: Button = %QuitButton
@onready var settings_menu: SettingsMenu = %SettingsMenu

## Services come from GameService (see GameService._inject_into_new_nodes); null when run without it.
var _checkpoints: CheckpointManager
var _input_manager: InputManager

func inject_services(registry: Node) -> void:
	_checkpoints = registry.get_service(&"checkpoint") as CheckpointManager
	_input_manager = registry.get_service(&"input") as InputManager

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)
	
	if settings_menu:
		settings_menu.visible = false
		settings_menu.back_pressed.connect(_on_settings_back)

func open_menu() -> void:
	visible = true
	if menu_panel:
		menu_panel.visible = true
	if settings_menu:
		settings_menu.visible = false
	if resume_button:
		resume_button.grab_focus()

func close_menu() -> void:
	visible = false
	if settings_menu:
		settings_menu.visible = false

func _on_resume_pressed() -> void:
	close_menu()
	resumed.emit()
	var im = _input_manager
	if im and im.has_method("capture_mouse"):
		im.capture_mouse()

func _on_settings_pressed() -> void:
	if menu_panel:
		menu_panel.visible = false
	if settings_menu:
		settings_menu.visible = true
		settings_menu.refresh_values()
		settings_menu.focus_first()
	settings_opened.emit()

func _on_settings_back() -> void:
	if settings_menu:
		settings_menu.visible = false
	if menu_panel:
		menu_panel.visible = true
	if settings_button:
		settings_button.grab_focus()

func _on_restart_pressed() -> void:
	close_menu()
	restart_checkpoint_requested.emit()
	var cm = _checkpoints
	if cm and cm.has_method("respawn_player"):
		cm.respawn_player()

func _on_quit_pressed() -> void:
	close_menu()
	quit_requested.emit()
	get_tree().paused = false
	var im = _input_manager
	if im:
		im.is_gameplay_paused = false
		im.mouse_captured = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file("res://game/scenes/Home/Home.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("pause"):
		if settings_menu and settings_menu.visible:
			_on_settings_back()
		else:
			_on_resume_pressed()
		get_viewport().set_input_as_handled()
