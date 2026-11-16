class_name LevelClearScreen
extends CanvasLayer

## Project: Lockdown - Level Clear Screen (Milestone 8)
## Shown when player reaches the exit trigger at the top of Stair B.
## Displays elapsed time, teammate rescue status, and restart button.

signal restart_requested()

@onready var time_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TimeLabel
@onready var rescue_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/RescueLabel
@onready var restart_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/RestartButton
@onready var hint_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HintLabel

var _can_restart: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)

func show_screen(elapsed_seconds: float, rescued: bool) -> void:
	visible = true
	_can_restart = false
	
	var mins: int = int(elapsed_seconds) / 60
	var secs: int = int(elapsed_seconds) % 60
	var msecs: int = int((elapsed_seconds - floor(elapsed_seconds)) * 100)
	var time_str: String = "%02d:%02d.%02d" % [mins, secs, msecs]
	
	if time_label:
		time_label.text = "Time: %s" % time_str
	
	if rescue_label:
		if rescued:
			rescue_label.text = "Officer Walker Rescued: YES"
			rescue_label.modulate = Color(0.3, 0.9, 0.4) # Green
		else:
			rescue_label.text = "Officer Walker Rescued: NO"
			rescue_label.modulate = Color(0.9, 0.35, 0.35) # Red / alert
	
	if hint_label:
		var im = get_node_or_null("/root/InputManager")
		var key = im.get_action_key_label("interact") if im else "E"
		var jump = im.get_action_key_label("jump") if im else "Space"
		hint_label.text = "Press [%s] or [%s] to restart" % [key, jump]
	
	# Short buffer to prevent accidental instant skip
	await get_tree().create_timer(0.3, true, false, true).timeout
	_can_restart = true
	if restart_button:
		restart_button.grab_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not _can_restart:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("jump"):
		if not event.is_echo():
			_on_restart_pressed()
			get_viewport().set_input_as_handled()

func _on_restart_pressed() -> void:
	if not _can_restart:
		return
	restart_requested.emit()
	var im = get_node_or_null("/root/InputManager")
	if im:
		im.is_level_clear_active = false
		im.capture_mouse()
	var cm = get_node_or_null("/root/CheckpointManager")
	if cm and cm.has_method("reset_session"):
		cm.reset_session()
	get_tree().paused = false
	var target_path: String = "res://game/scenes/gameplay/levels/Floor01.tscn"
	if get_tree().current_scene and not get_tree().current_scene.scene_file_path.is_empty():
		target_path = get_tree().current_scene.scene_file_path
	queue_free()
	get_tree().change_scene_to_file(target_path)
