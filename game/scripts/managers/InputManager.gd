extends Node

## InputManager handles input routing, mouse capture, look delta aggregation,
## pause toggling, and action key/button label formatting for UI prompts.

signal mouse_capture_changed(is_captured: bool)
signal pause_toggled(is_paused: bool)

enum InputDevice {
	MOUSE_KEYBOARD,
	GAMEPAD,
	TOUCH
}

var last_input_device: InputDevice = InputDevice.MOUSE_KEYBOARD

var mouse_sensitivity: float = 0.002
var controller_look_speed: float = 3.0
var touch_sens_h: float = 0.0025
var touch_sens_v: float = 0.0020
var touch_smoothing: float = 0.0
var gyro_mode: int = 0 # 0 = Off, 1 = Always, 2 = While firing
var gyro_sensitivity: float = 1.0
var _mock_gyroscope: Vector3 = Vector3.ZERO
var _use_mock_gyro: bool = false
var invert_y: bool = false
var mouse_captured: bool = false
var is_gameplay_paused: bool = false
var is_death_screen_active: bool = false
var is_level_clear_active: bool = false
var just_recaptured: bool = false
var _recaptured_frames: int = 0
var _mouse_delta: Vector2 = Vector2.ZERO
var _touch_delta: Vector2 = Vector2.ZERO

func is_touch_device() -> bool:
	var sm = get_node_or_null("/root/SettingsManager")
	if sm and sm.touch_controls_mode == 1:
		return true
	if sm and sm.touch_controls_mode == 2:
		return false
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")

func is_last_input_touch() -> bool:
	if is_touch_device():
		return true
	return last_input_device == InputDevice.TOUCH

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.use_accumulated_input = false
	_setup_clean_input_map()
	get_tree().set_auto_accept_quit(false)
	
	if not is_touch_device():
		capture_mouse()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		mouse_captured = true
		is_gameplay_paused = false
		last_input_device = InputDevice.TOUCH
	
	var sm = get_node_or_null("/root/SettingsManager")
	if sm and sm.has_signal("settings_changed"):
		sm.settings_changed.connect(_on_settings_changed)

func _on_settings_changed(key: String, _val: Variant) -> void:
	if key == "touch_controls_mode":
		if is_touch_device():
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			last_input_device = InputDevice.TOUCH
		else:
			if not is_gameplay_paused and not is_death_screen_active and not is_level_clear_active:
				if get_tree().current_scene and get_tree().current_scene.name != "MainMenu":
					capture_mouse()

func _process(_delta: float) -> void:
	if just_recaptured:
		if _recaptured_frames > 0:
			_recaptured_frames -= 1
		else:
			just_recaptured = false

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_handle_go_back_request()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			_handle_app_paused_or_focus_out()

func _handle_go_back_request() -> void:
	if is_death_screen_active or is_level_clear_active:
		return
	
	if get_tree().current_scene and get_tree().current_scene.name == "MainMenu":
		get_tree().quit()
		return
	
	var pause_menu = get_tree().root.find_child("PauseMenu", true, false)
	if pause_menu and is_instance_valid(pause_menu):
		var settings_menu = pause_menu.find_child("SettingsMenu", true, false)
		if settings_menu and settings_menu.visible:
			settings_menu._on_back_pressed()
			return
		toggle_pause()
	else:
		toggle_pause()

func _handle_app_paused_or_focus_out() -> void:
	if is_gameplay_paused or is_death_screen_active or is_level_clear_active:
		return
	if get_tree().current_scene and get_tree().current_scene.name == "MainMenu":
		return
	pause_gameplay()

func configure_from_player_data(data: PlayerData) -> void:
	if not data:
		return
	mouse_sensitivity = data.mouse_sensitivity
	controller_look_speed = data.controller_look_speed
	invert_y = data.invert_y

func capture_mouse() -> void:
	if is_touch_device():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		mouse_captured = true
		is_gameplay_paused = false
		if get_tree():
			get_tree().paused = false
		just_recaptured = false
		mouse_capture_changed.emit(true)
		pause_toggled.emit(false)
		return
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mouse_captured = true
	is_gameplay_paused = false
	if get_tree():
		get_tree().paused = false
	just_recaptured = true
	_recaptured_frames = 2
	mouse_capture_changed.emit(true)
	pause_toggled.emit(false)

func release_mouse() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	mouse_captured = false
	is_gameplay_paused = true
	if get_tree():
		get_tree().paused = true
	just_recaptured = false
	_recaptured_frames = 0
	_mouse_delta = Vector2.ZERO
	_touch_delta = Vector2.ZERO
	mouse_capture_changed.emit(false)
	pause_toggled.emit(true)

func toggle_mouse_capture() -> void:
	if mouse_captured:
		release_mouse()
	else:
		capture_mouse()

func toggle_pause() -> void:
	if is_gameplay_paused:
		resume_gameplay()
	else:
		pause_gameplay()

func pause_gameplay() -> void:
	if is_death_screen_active or is_level_clear_active:
		return
	release_mouse()

func resume_gameplay() -> void:
	capture_mouse()

func inject_touch_look(rel: Vector2) -> void:
	last_input_device = InputDevice.TOUCH
	if not (get_tree() and get_tree().paused):
		_touch_delta += rel

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		last_input_device = InputDevice.TOUCH
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		last_input_device = InputDevice.GAMEPAD
	elif event is InputEventKey:
		last_input_device = InputDevice.MOUSE_KEYBOARD
	elif event is InputEventMouseButton or event is InputEventMouseMotion:
		if not is_touch_device():
			last_input_device = InputDevice.MOUSE_KEYBOARD
	
	if is_death_screen_active or is_level_clear_active:
		return
	
	# 1. Escape / Start / Pause -> Toggle Pause
	if event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()
		return
	
	# 2. Left-click to recapture mouse when released (desktop mouse only, never touch devices, never in pause menu)
	if not is_touch_device() and event is InputEventMouseButton and event.pressed and not mouse_captured and not is_gameplay_paused:
		if event.button_index == MOUSE_BUTTON_LEFT:
			capture_mouse()
			Input.action_release("fire")
			get_viewport().set_input_as_handled()
			return

func _unhandled_input(event: InputEvent) -> void:
	if is_touch_device():
		return
	# Mouse Motion (only when captured and tree is not paused)
	if event is InputEventMouseMotion and mouse_captured and not (get_tree() and get_tree().paused):
		_mouse_delta += event.relative
		return

func set_mock_gyroscope(gyro: Vector3, enabled: bool = true) -> void:
	_mock_gyroscope = gyro
	_use_mock_gyro = enabled

## Returns accumulated look rotation delta in radians: Vector2(yaw_delta, pitch_delta)
func get_look_delta(delta: float) -> Vector2:
	if (get_tree() and get_tree().paused):
		_mouse_delta = Vector2.ZERO
		_touch_delta = Vector2.ZERO
		return Vector2.ZERO
	
	var look: Vector2 = Vector2.ZERO
	
	# Touch drag look
	if _touch_delta != Vector2.ZERO:
		look.x += _touch_delta.x * touch_sens_h
		look.y += _touch_delta.y * touch_sens_v
		_touch_delta = Vector2.ZERO
	
	# Mouse look (only desktop when captured)
	if not is_touch_device():
		if mouse_captured and not just_recaptured and _mouse_delta != Vector2.ZERO:
			look += _mouse_delta * mouse_sensitivity
			_mouse_delta = Vector2.ZERO
	
	var action_look: Vector2 = Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if action_look != Vector2.ZERO:
		look.x += action_look.x * controller_look_speed * delta
		look.y += action_look.y * controller_look_speed * delta
	
	# Gyroscope Look (phones with gyro sensor, disabled on devices without gyroscope)
	if gyro_mode != 0:
		var is_firing = Input.is_action_pressed("fire")
		var is_gyro_active = (gyro_mode == 1) or (gyro_mode == 2 and is_firing)
		if is_gyro_active:
			var gyro_raw: Vector3 = _mock_gyroscope if _use_mock_gyro else Input.get_gyroscope()
			if gyro_raw != Vector3.ZERO:
				var gyro_look = Vector2(-gyro_raw.y, -gyro_raw.x) * gyro_sensitivity * delta * 1.5
				look += gyro_look
	
	if invert_y:
		look.y = -look.y
	
	return look

## Returns human-readable label of key/button bound to action
func get_action_key_label(action_name: String) -> String:
	if not InputMap.has_action(action_name):
		return ""
	
	var events: Array[InputEvent] = InputMap.action_get_events(action_name)
	for ev in events:
		if ev is InputEventKey:
			var code = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
			var key_str = OS.get_keycode_string(code)
			if not key_str.is_empty():
				return key_str
		elif ev is InputEventMouseButton:
			match ev.button_index:
				MOUSE_BUTTON_LEFT: return "LMB"
				MOUSE_BUTTON_RIGHT: return "RMB"
				MOUSE_BUTTON_MIDDLE: return "MMB"
				_: return "Mouse"
		elif ev is InputEventJoypadButton:
			match ev.button_index:
				JoyButton.JOY_BUTTON_A: return "A"
				JoyButton.JOY_BUTTON_B: return "B"
				JoyButton.JOY_BUTTON_X: return "X"
				JoyButton.JOY_BUTTON_Y: return "Y"
				JoyButton.JOY_BUTTON_LEFT_SHOULDER: return "LB"
				JoyButton.JOY_BUTTON_RIGHT_SHOULDER: return "RB"
				JoyButton.JOY_BUTTON_START: return "Start"
				JoyButton.JOY_BUTTON_LEFT_STICK: return "L3"
				_: return "Btn"
		elif ev is InputEventJoypadMotion:
			match ev.axis:
				JoyAxis.JOY_AXIS_TRIGGER_LEFT: return "LT"
				JoyAxis.JOY_AXIS_TRIGGER_RIGHT: return "RT"
				_: return "Trigger"
	
	return "E"

func format_action_prompt(action_name: String, action_description: String) -> String:
	var key = get_action_key_label(action_name)
	return "[%s] %s" % [key, action_description]

## Configures the exact InputMap requested with zero duplicate key bindings:
## fire=LMB/RT, block=RMB/LT, melee=F/RB, reload=R/X, interact=E/Y, jump=Space/A,
## crouch=LeftCtrl/B, sprint=LeftShift/L3, pause=Escape/Start, move=WASD/LeftStick,
## look=mouse/RightStick.
func _setup_clean_input_map() -> void:
	var actions = [
		"fire", "block", "melee", "reload", "interact", "jump",
		"crouch", "sprint", "pause", "move_forward", "move_back",
		"move_left", "move_right", "look", "look_left", "look_right",
		"look_up", "look_down"
	]
	
	var all_configured: bool = true
	for action in actions:
		if not InputMap.has_action(action) or InputMap.action_get_events(action).is_empty():
			all_configured = false
			break
	
	if all_configured:
		return
	
	for action in actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		else:
			InputMap.action_erase_events(action)
	
	# Fire: LMB / RT
	_add_mouse_event("fire", MOUSE_BUTTON_LEFT)
	_add_joy_motion_event("fire", JoyAxis.JOY_AXIS_TRIGGER_RIGHT, 1.0)
	
	# Block: RMB / LT (hold)
	_add_mouse_event("block", MOUSE_BUTTON_RIGHT)
	_add_joy_motion_event("block", JoyAxis.JOY_AXIS_TRIGGER_LEFT, 1.0)
	
	# Melee: F / RB
	_add_key_event("melee", KEY_F)
	_add_joy_button_event("melee", JoyButton.JOY_BUTTON_RIGHT_SHOULDER)
	
	# Reload: R / X
	_add_key_event("reload", KEY_R)
	_add_joy_button_event("reload", JoyButton.JOY_BUTTON_X)
	
	# Interact: E / Y
	_add_key_event("interact", KEY_E)
	_add_joy_button_event("interact", JoyButton.JOY_BUTTON_Y)
	
	# Jump: Space / A
	_add_key_event("jump", KEY_SPACE)
	_add_joy_button_event("jump", JoyButton.JOY_BUTTON_A)
	
	# Crouch: LeftCtrl / B (C removed)
	_add_key_event("crouch", KEY_CTRL)
	_add_joy_button_event("crouch", JoyButton.JOY_BUTTON_B)
	
	# Sprint: LeftShift / L3
	_add_key_event("sprint", KEY_SHIFT)
	_add_joy_button_event("sprint", JoyButton.JOY_BUTTON_LEFT_STICK)
	
	# Pause: Escape / Start
	_add_key_event("pause", KEY_ESCAPE)
	_add_joy_button_event("pause", JoyButton.JOY_BUTTON_START)
	
	# Move: WASD / Left Stick
	_add_key_event("move_forward", KEY_W)
	_add_joy_motion_event("move_forward", JoyAxis.JOY_AXIS_LEFT_Y, -1.0)
	
	_add_key_event("move_back", KEY_S)
	_add_joy_motion_event("move_back", JoyAxis.JOY_AXIS_LEFT_Y, 1.0)
	
	_add_key_event("move_left", KEY_A)
	_add_joy_motion_event("move_left", JoyAxis.JOY_AXIS_LEFT_X, -1.0)
	
	_add_key_event("move_right", KEY_D)
	_add_joy_motion_event("move_right", JoyAxis.JOY_AXIS_LEFT_X, 1.0)
	
	# Look: Right Stick (Mouse motion handled directly)
	_add_joy_motion_event("look_left", JoyAxis.JOY_AXIS_RIGHT_X, -1.0)
	_add_joy_motion_event("look_right", JoyAxis.JOY_AXIS_RIGHT_X, 1.0)
	_add_joy_motion_event("look_up", JoyAxis.JOY_AXIS_RIGHT_Y, -1.0)
	_add_joy_motion_event("look_down", JoyAxis.JOY_AXIS_RIGHT_Y, 1.0)

func _add_key_event(action: String, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)

func _add_mouse_event(action: String, button: MouseButton) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)

func _add_joy_button_event(action: String, button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	InputMap.action_add_event(action, event)

func _add_joy_motion_event(action: String, axis: JoyAxis, direction: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = direction
	InputMap.action_add_event(action, event)

func get_binding_table_string() -> String:
	var actions = [
		"fire", "block", "melee", "reload", "interact", "jump",
		"crouch", "sprint", "pause", "move_forward", "move_back",
		"move_left", "move_right", "look_left", "look_right", "look_up", "look_down"
	]
	var out = "=== PROJECT: LOCKDOWN INPUTMAP BINDING TABLE ===\n"
	for act in actions:
		var evs = InputMap.action_get_events(act)
		var ev_strs = []
		for ev in evs:
			ev_strs.append(ev.as_text())
		out += "%-14s : %s\n" % [act, ", ".join(ev_strs)]
	return out
