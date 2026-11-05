class_name MainMenu
extends Control

## Project: Lockdown - Main Menu (Milestone 9)
## Title: PROJECT: LOCKDOWN
## Options: Start Operation, System Settings, Quit (hidden on mobile).

@onready var start_button: Button = %StartButton
@onready var settings_button: Button = %SettingsButton
@onready var quit_button: Button = %QuitButton
@onready var settings_menu: SettingsMenu = %SettingsMenu
@onready var menu_buttons_container: Control = %MenuButtons

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	var im = get_node_or_null("/root/InputManager")
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
	
	if settings_menu:
		settings_menu.visible = false
		settings_menu.back_pressed.connect(_on_settings_back)

func _on_start_pressed() -> void:
	var cm = get_node_or_null("/root/CheckpointManager")
	if cm and cm.has_method("reset_session"):
		cm.reset_session()
	
	var im = get_node_or_null("/root/InputManager")
	if im and im.has_method("capture_mouse"):
		im.capture_mouse()
	
	get_tree().change_scene_to_file("res://scenes/levels/floor_01.tscn")

func _on_settings_pressed() -> void:
	if menu_buttons_container:
		menu_buttons_container.visible = false
	if settings_menu:
		settings_menu.visible = true
		settings_menu.refresh_values()
		settings_menu.focus_first()

func _on_settings_back() -> void:
	if settings_menu:
		settings_menu.visible = false
	if menu_buttons_container:
		menu_buttons_container.visible = true
	if settings_button:
		settings_button.grab_focus()

func _on_quit_pressed() -> void:
	get_tree().quit(0)
