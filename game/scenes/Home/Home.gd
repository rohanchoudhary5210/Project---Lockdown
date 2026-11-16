class_name Home
extends Control

## Project: Lockdown - Home / main menu (Milestone 9)
## Title: PROJECT: LOCKDOWN
## Options: Start Operation, System Settings, Quit (hidden on mobile).

@onready var start_button: Button = %StartButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var menu_buttons_container: Control = %MenuButtons

## Services come from GameService (see GameService._inject_into_new_nodes); null when run without it.
var _checkpoints: CheckpointManager
var _input_manager: InputManager
var _ui: UIManager
var _game: GameManager
var _scene: SceneManager

const SETTINGS_SCENE: PackedScene = preload("res://game/scenes/ui/mfw/SettingsMenu.tscn")
const FIRST_LEVEL: String = "res://game/scenes/gameplay/levels/GroundFloor.tscn"

func inject_services(registry: Node) -> void:
	_ui = registry.get_service(&"ui") as UIManager
	_game = registry.get_service(&"game") as GameManager
	_scene = registry.get_service(&"scene") as SceneManager
	_checkpoints = registry.get_service(&"checkpoint") as CheckpointManager
	_input_manager = registry.get_service(&"input") as InputManager

func _enter_tree() -> void:
	ServiceBootstrap.ensure(self)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	if _game:
		_game.reset()
	if _ui:
		while _ui.stack_size() > 0: # nothing from the previous level stays open
			_ui.pop()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	var im = _input_manager
	if im:
		im.mouse_captured = false
		im.is_gameplay_paused = false
		im.is_death_screen_active = false
		im.is_level_clear_active = false
	
	if quit_button:
		# Hide Quit button on mobile devices (Android / iOS / Web)
		if OS.has_feature("mobile") or OS.has_feature("web") or OS.get_name() in ["Android", "iOS"]:
			quit_button.visible = false
	
	if start_button:
		start_button.pressed.connect(_on_start_pressed)
		start_button.grab_focus()
	if settings_button:
		settings_button.pressed.connect(_on_settings_pressed)
	if quit_button:
		quit_button.pressed.connect(_on_quit_pressed)

func _on_start_pressed() -> void:
	var cm = _checkpoints
	if cm and cm.has_method("reset_session"):
		cm.reset_session()
	
	var im = _input_manager
	if im and im.has_method("capture_mouse"):
		im.capture_mouse()
	
	_scene.go_to(FIRST_LEVEL)

func _on_settings_pressed() -> void:
	if menu_buttons_container:
		menu_buttons_container.visible = false
	_ui.push_packed(SETTINGS_SCENE)
	var settings := _ui.current() as SettingsMenu
	settings.back_pressed.connect(_on_settings_back)
	settings.refresh_values()
	settings.focus_first()

func _on_settings_back() -> void:
	if menu_buttons_container:
		menu_buttons_container.visible = true
	if settings_button:
		settings_button.grab_focus()

func _on_quit_pressed() -> void:
	get_tree().quit(0)
