class_name TouchControls
extends Control

## Project: Lockdown - PUBG Mobile Style Touch Controls
## Floating/Following virtual joystick in fixed bottom-left zone with Sprint Lock.
## Left and Main Fire buttons supporting fire-and-drag aiming.
## Bottom-right action cluster (Jump, Crouch toggle, Reload), Melee and Block (hold).
## Dynamic contextual Interact button (Hold-to-Rescue compatible).
## In-game HUD Customization Mode (drag reposition, 0.6x-1.5x resize, global opacity, per-aspect ratio persistence).

const JOYSTICK_RADIUS: float = 75.0
const JOYSTICK_DEADZONE: float = 8.0

const LOOK_DEADZONE_SPEED: float = 10.0 # px/s; below this the finger is resting (tremor), not aiming
const LOOK_CURVE_EXPONENT: float = 1.3
const LOOK_CURVE_REF_SPEED: float = 60.0 # px/s; matches the old per-event curve when one event arrives per 60 FPS frame
const LOOK_TIME_CONSTANT: float = 0.025 # ~25ms time constant (low lag, buttery smooth)

@onready var buttons_container: Control = %ButtonsContainer
@onready var pause_button: TouchButton = %PauseButton
@onready var left_fire_button: TouchButton = %LeftFireButton
@onready var fire_button: TouchButton = %FireButton
@onready var block_button: TouchButton = %BlockButton
@onready var melee_button: TouchButton = %MeleeButton
@onready var jump_button: TouchButton = %JumpButton
@onready var crouch_button: TouchButton = %CrouchButton
@onready var reload_button: TouchButton = %ReloadButton
@onready var interact_button: TouchButton = %InteractButton

# Edit Mode Toolbar
@onready var edit_toolbar: PanelContainer = %EditToolbar
@onready var scale_slider: HSlider = %ScaleSlider
@onready var scale_value: Label = %ScaleValue
@onready var opacity_slider: HSlider = %OpacitySlider
@onready var opacity_value: Label = %OpacityValue
@onready var reset_button: Button = %ResetButton
@onready var save_exit_button: Button = %SaveExitButton

# Joystick State
var _joystick_touch_index: int = -1
var _joystick_active: bool = false
var _joystick_center: Vector2 = Vector2.ZERO
var _joystick_current: Vector2 = Vector2.ZERO
var _default_joystick_pos: Vector2 = Vector2.ZERO
var _sprint_locked: bool = false

# Look State
var _look_touch_index: int = -1
var _is_mouse_joystick: bool = false
var _is_mouse_look: bool = false
var _smoothed_look_rate: Vector2 = Vector2.ZERO
var _accumulated_drag: Vector2 = Vector2.ZERO
var _look_speed_est: float = 0.0

# Edit Mode State
var _is_edit_mode: bool = false
var _selected_button: TouchButton = null
var _edit_drag_touch_id: int = -1
var _edit_drag_offset: Vector2 = Vector2.ZERO
var _global_opacity: float = 1.0

## Services come from GameService (see GameService._inject_into_new_nodes); null when run without it.
var _input_manager: InputManager
var _settings: SettingsManager

func inject_services(registry: Node) -> void:
	_input_manager = registry.get_service(&"input") as InputManager
	_settings = registry.get_service(&"settings") as SettingsManager

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -10
	mouse_filter = Control.MOUSE_FILTER_PASS
	Input.use_accumulated_input = false
	
	if interact_button:
		interact_button.visible = false
	if pause_button:
		pause_button.button_pressed.connect(_on_pause_pressed)
	
	# Connect fire-and-drag signals
	if fire_button:
		fire_button.touch_dragged.connect(_on_fire_dragged)
	if left_fire_button:
		left_fire_button.touch_dragged.connect(_on_fire_dragged)
	
	# Connect edit toolbar signals
	if scale_slider:
		scale_slider.value_changed.connect(_on_scale_slider_changed)
	if opacity_slider:
		opacity_slider.value_changed.connect(_on_opacity_slider_changed)
	if reset_button:
		reset_button.pressed.connect(_on_reset_layout_pressed)
	if save_exit_button:
		save_exit_button.pressed.connect(_on_save_exit_pressed)
	
	if edit_toolbar:
		edit_toolbar.visible = false
	
	_update_visibility()
	
	var sm = _settings
	if sm and sm.has_signal("settings_changed"):
		sm.settings_changed.connect(_on_settings_changed)
	
	call_deferred("_bind_player_signals")
	call_deferred("_initialize_layout")

func _initialize_layout() -> void:
	_update_layout_and_safe_area()
	load_layout_for_aspect_ratio()

func _bind_player_signals() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_signal("interaction_prompt_changed"):
		if not player.interaction_prompt_changed.is_connected(_on_prompt_changed):
			player.interaction_prompt_changed.connect(_on_prompt_changed)

func _on_prompt_changed(prompt_text: String) -> void:
	if _is_edit_mode:
		return
	if interact_button:
		if prompt_text.is_empty():
			interact_button.visible = false
		else:
			interact_button.visible = true
			interact_button.button_label_text = _format_prompt_label(prompt_text)

func _format_prompt_label(prompt: String) -> String:
	var upper = prompt.to_upper()
	if "RESCUE" in upper:
		return "RESCUE"
	if "AMMO" in upper:
		return "AMMO"
	if "DOOR" in upper or "OPEN" in upper:
		return "DOOR"
	if "REVIVE" in upper:
		return "REVIVE"
	if "GRAB" in upper or "TAKE" in upper:
		return "TAKE"
	return "USE"

func _on_settings_changed(key: String, _val: Variant) -> void:
	if key == "touch_controls_mode":
		_update_visibility()

func _update_visibility() -> void:
	if _is_edit_mode:
		visible = true
		set_process_input(true)
		set_process_unhandled_input(true)
		return
	
	var sm = _settings
	var should_show: bool = false
	if sm and sm.has_method("should_show_touch_controls"):
		should_show = sm.should_show_touch_controls()
	else:
		should_show = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	
	visible = should_show
	set_process_input(should_show)
	set_process_unhandled_input(should_show)
	
	if not should_show:
		_reset_joystick()
		_look_touch_index = -1
		_smoothed_look_rate = Vector2.ZERO
		_accumulated_drag = Vector2.ZERO

func _process(delta: float) -> void:
	if not visible:
		return
	if delta <= 0.00001:
		return
	
	var is_look_active = (_look_touch_index != -1) or _is_mouse_look
	if not is_look_active and _accumulated_drag == Vector2.ZERO:
		_smoothed_look_rate = Vector2.ZERO
		_look_speed_est = 0.0
		return
	
	var raw_frame_delta = _accumulated_drag
	_accumulated_drag = Vector2.ZERO

	# Curve on the finger's speed over this frame, not on single touch events, so the result
	# doesn't depend on the phone's touch rate or the frame rate.
	# Speed is averaged over ~50ms because touch events don't arrive evenly every frame.
	var speed_alpha: float = 1.0 - exp(-delta / 0.05)
	_look_speed_est = lerpf(_look_speed_est, raw_frame_delta.length() / delta, speed_alpha)
	var speed: float = _look_speed_est
	var compensated_frame_delta: Vector2 = Vector2.ZERO
	if speed >= LOOK_DEADZONE_SPEED:
		# Never slower than 1:1, so slow precise aiming isn't damped; only fast swipes speed up.
		var gain: float = clampf(pow(speed / LOOK_CURVE_REF_SPEED, LOOK_CURVE_EXPONENT - 1.0), 1.0, 3.0)
		compensated_frame_delta = raw_frame_delta * gain
	
	# Frame-rate independent exponential smoothing (~25ms time constant)
	var target_rate = compensated_frame_delta / delta
	var alpha = 1.0 - exp(-delta / LOOK_TIME_CONSTANT)
	_smoothed_look_rate = _smoothed_look_rate.lerp(target_rate, alpha)
	var smoothed_frame_delta = _smoothed_look_rate * delta
	
	var sm = _settings
	var smoothing_factor: float = sm.touch_smoothing if sm else 0.0
	var final_frame_delta = compensated_frame_delta.lerp(smoothed_frame_delta, smoothing_factor)
	
	if final_frame_delta != Vector2.ZERO:
		_inject_look_motion(final_frame_delta)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	
	if _is_edit_mode:
		_handle_edit_input(event)
		return
	
	# Normal gameplay touch handling
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)
	
	# Desktop debug mouse emulation
	var sm = _settings
	if sm and sm.touch_controls_mode == 1:
		if event is InputEventMouseButton:
			_handle_mouse_button(event)
		elif event is InputEventMouseMotion:
			_handle_mouse_motion(event)

func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	var vp_size = get_viewport_rect().size
	var half_x = vp_size.x * 0.5
	
	if event.pressed:
		if _is_touch_on_any_button(event.position):
			return
		
		# Left half (outside buttons): joystick appears where the thumb lands
		if event.position.x < half_x:
			# If sprint locked, a tap inside joystick zone cancels it
			if _sprint_locked:
				_sprint_locked = false
				_release_movement_actions()
			
			if _joystick_touch_index == -1:
				_joystick_touch_index = event.index
				_joystick_active = true
				_joystick_center = event.position
				_joystick_current = event.position
				queue_redraw()
		elif event.position.x >= half_x:
			# Right half: start drag to look
			if _look_touch_index == -1:
				_look_touch_index = event.index
				_smoothed_look_rate = Vector2.ZERO
				_accumulated_drag = Vector2.ZERO
	else:
		if event.index == _joystick_touch_index:
			_reset_joystick()
		elif event.index == _look_touch_index:
			_look_touch_index = -1
			_smoothed_look_rate = Vector2.ZERO
			_accumulated_drag = Vector2.ZERO

func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	if event.index == _joystick_touch_index:
		_update_joystick_drag(event.position)
	elif event.index == _look_touch_index:
		_process_look_drag_event(event.relative)

func _handle_mouse_button(event: InputEventMouseButton) -> void:
	var vp_size = get_viewport_rect().size
	var half_x = vp_size.x * 0.5
	
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _is_touch_on_any_button(event.position):
				return
			if event.position.x < half_x:
				if _sprint_locked:
					_sprint_locked = false
					_release_movement_actions()
				_is_mouse_joystick = true
				_joystick_active = true
				_joystick_center = event.position
				_joystick_current = event.position
				queue_redraw()
			elif event.position.x >= half_x:
				_is_mouse_look = true
				_smoothed_look_rate = Vector2.ZERO
				_accumulated_drag = Vector2.ZERO
		else:
			if _is_mouse_joystick:
				_is_mouse_joystick = false
				_reset_joystick()
			if _is_mouse_look:
				_is_mouse_look = false
				_smoothed_look_rate = Vector2.ZERO
				_accumulated_drag = Vector2.ZERO

func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _is_mouse_joystick:
		_update_joystick_drag(event.position)
	elif _is_mouse_look:
		_process_look_drag_event(event.relative)

## Fire-and-drag handler: dragging from either fire button directly aims
func _on_fire_dragged(relative: Vector2, _index: int) -> void:
	if not _is_edit_mode:
		_process_look_drag_event(relative)

func _process_look_drag_event(raw_relative: Vector2) -> void:
	# Keep every event, however small; deadzone and curve are applied per frame in _process
	_accumulated_drag += raw_relative

func _update_joystick_drag(pos: Vector2) -> void:
	var delta_vec: Vector2 = pos - _joystick_center
	var dist: float = delta_vec.length()
	
	# Following thumb drift: if thumb drags beyond radius, center follows smoothly
	if dist > JOYSTICK_RADIUS:
		var excess: float = dist - JOYSTICK_RADIUS
		_joystick_center += delta_vec.normalized() * (excess * 0.35)
		delta_vec = pos - _joystick_center
		dist = delta_vec.length()
	
	var clamped_vec = delta_vec.normalized() * minf(dist, JOYSTICK_RADIUS)
	_joystick_current = _joystick_center + clamped_vec
	
	# Sprint Lock: drag upward into lock area above joystick
	if delta_vec.y < -JOYSTICK_RADIUS * 1.15 and absf(delta_vec.x) < 45.0:
		_sprint_locked = true
	elif _sprint_locked and delta_vec.y > 20.0: # Pull backward cancels sprint lock
		_sprint_locked = false
		_release_movement_actions()
	
	if _sprint_locked:
		Input.action_press("move_forward")
		Input.action_press("sprint")
		Input.action_release("move_back")
		Input.action_release("move_left")
		Input.action_release("move_right")
		queue_redraw()
		return
	
	if dist > JOYSTICK_DEADZONE:
		# Linear, reaching full speed at 85% of the radius so the thumb doesn't have to hit the rim.
		var full_speed_dist: float = JOYSTICK_RADIUS * 0.85
		var t = clampf((dist - JOYSTICK_DEADZONE) / (full_speed_dist - JOYSTICK_DEADZONE), 0.0, 1.0)
		var speed_mult = t
		var dir = delta_vec.normalized()
		var norm = dir * speed_mult
		
		# Movement actions with analog strength
		if norm.x > 0.01:
			Input.action_press("move_right", norm.x)
			Input.action_release("move_left")
		elif norm.x < -0.01:
			Input.action_press("move_left", -norm.x)
			Input.action_release("move_right")
		else:
			Input.action_release("move_right")
			Input.action_release("move_left")
		
		if norm.y < -0.01:
			Input.action_press("move_forward", -norm.y)
			Input.action_release("move_back")
		elif norm.y > 0.01:
			Input.action_press("move_back", norm.y)
			Input.action_release("move_forward")
		else:
			Input.action_release("move_forward")
			Input.action_release("move_back")
		
		# No auto-sprint from a full push: sprinting is loud (enemies hear it), so it only
		# happens through the sprint lock above.
		Input.action_release("sprint")
	else:
		_release_movement_actions()
	
	queue_redraw()

func _reset_joystick() -> void:
	_joystick_touch_index = -1
	_joystick_active = false
	if not _sprint_locked:
		_release_movement_actions()
	queue_redraw()

func _release_movement_actions() -> void:
	Input.action_release("move_forward")
	Input.action_release("move_back")
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("sprint")

func _inject_look_motion(rel: Vector2) -> void:
	var im = _input_manager
	if im and im.has_method("inject_touch_look"):
		im.inject_touch_look(rel)
	else:
		var mm = InputEventMouseMotion.new()
		mm.relative = rel
		Input.parse_input_event(mm)

func _is_touch_on_any_button(pos: Vector2) -> bool:
	var buttons = _get_all_buttons()
	for b in buttons:
		if b and is_instance_valid(b) and b.is_visible_in_tree():
			if b.get_global_rect().has_point(pos):
				return true
	return false

func _get_all_buttons() -> Array[TouchButton]:
	var list: Array[TouchButton] = []
	var arr = [pause_button, left_fire_button, fire_button, block_button, melee_button, jump_button, crouch_button, reload_button, interact_button]
	for b in arr:
		if b and is_instance_valid(b):
			list.append(b)
	return list

func set_paused(is_paused: bool) -> void:
	if is_paused:
		visible = false
		set_process_input(false)
		set_process_unhandled_input(false)
		_reset_joystick()
		_sprint_locked = false
		_look_touch_index = -1
		_is_mouse_joystick = false
		_is_mouse_look = false
		_smoothed_look_rate = Vector2.ZERO
		_accumulated_drag = Vector2.ZERO
		_force_release_all_buttons()
	else:
		_update_visibility()

func _force_release_all_buttons() -> void:
	for b in _get_all_buttons():
		if b and b.has_method("force_release"):
			b.force_release()

func _on_pause_pressed() -> void:
	if _is_edit_mode:
		return
	var im = _input_manager
	if im and im.has_method("pause_gameplay"):
		im.pause_gameplay()
	elif im and im.has_method("toggle_pause"):
		im.toggle_pause()

# -----------------------------------------------------------------------------
# DRAWING (Procedural Joysticks & Sprint Lock)
# -----------------------------------------------------------------------------
func _draw() -> void:
	var resting_center = _default_joystick_pos
	var current_center = _joystick_center if _joystick_active else resting_center
	var current_knob = _joystick_current if _joystick_active else resting_center
	
	# Draw resting / active outer base ring
	var base_col = Color(0.18, 0.22, 0.3, 0.4 if _joystick_active else 0.25)
	var outline_col = Color(0.3, 0.7, 1.0, 0.7 if _joystick_active else 0.4)
	draw_circle(current_center, JOYSTICK_RADIUS, base_col)
	draw_arc(current_center, JOYSTICK_RADIUS, 0, TAU, 32, outline_col, 2.0)
	
	# Sprint Lock Icon above joystick
	var lock_center = Vector2(current_center.x, current_center.y - JOYSTICK_RADIUS * 1.45)
	var lock_col = Color(1.0, 0.5, 0.1, 0.95) if _sprint_locked else Color(0.5, 0.8, 1.0, 0.5)
	var lock_bg = Color(0.15, 0.18, 0.25, 0.75) if _sprint_locked else Color(0.1, 0.12, 0.16, 0.45)
	draw_circle(lock_center, 22.0, lock_bg)
	draw_arc(lock_center, 22.0, 0, TAU, 24, lock_col, 2.0)
	
	# Arrow / Lock indicator
	var font = ThemeDB.fallback_font
	var lock_text = "LOCKED" if _sprint_locked else "^ RUN"
	var text_size = font.get_string_size(lock_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
	draw_string(font, lock_center + Vector2(-text_size.x * 0.5, 4.0), lock_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 10, lock_col)
	
	# Draw thumb knob
	var knob_col = Color(0.4, 0.85, 1.0, 0.85 if _joystick_active else 0.5)
	draw_circle(current_knob, 26.0, knob_col)
	draw_arc(current_knob, 26.0, 0, TAU, 24, Color.WHITE, 2.0)
	
	# Edit Mode dashed zone indicator for joystick
	if _is_edit_mode:
		var zone_rect = Rect2(Vector2(20, 20), Vector2(get_viewport_rect().size.x * 0.5 - 40, get_viewport_rect().size.y - 40))
		draw_rect(zone_rect, Color(0.3, 0.7, 1.0, 0.15), true)
		draw_rect(zone_rect, Color(0.3, 0.8, 1.0, 0.6), false, 2.0)
		var zone_label = "JOYSTICK ZONE"
		var zs = font.get_string_size(zone_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13)
		draw_string(font, zone_rect.position + Vector2(10, 20), zone_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.4, 0.9, 1.0, 0.8))

# -----------------------------------------------------------------------------
# SAFE AREA & DEFAULT LAYOUTS
# -----------------------------------------------------------------------------
func _update_layout_and_safe_area() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	if vp_size.x <= 0 or vp_size.y <= 0:
		return
	
	var safe_area: Rect2i = DisplayServer.get_display_safe_area()
	var window_size: Vector2i = DisplayServer.window_get_size()
	if window_size.x <= 0 or window_size.y <= 0:
		window_size = Vector2i(int(vp_size.x), int(vp_size.y))
	if safe_area.size.x <= 0 or safe_area.size.y <= 0:
		safe_area = Rect2i(Vector2i.ZERO, window_size)
	
	var scale_x: float = vp_size.x / float(window_size.x)
	var scale_y: float = vp_size.y / float(window_size.y)
	
	var safe_left: float = maxf(float(safe_area.position.x) * scale_x, 24.0)
	var safe_top: float = maxf(float(safe_area.position.y) * scale_y, 24.0)
	var safe_right: float = maxf(float(window_size.x - safe_area.end.x) * scale_x, 24.0)
	var safe_bottom: float = maxf(float(window_size.y - safe_area.end.y) * scale_y, 24.0)
	
	# Default joystick position
	_default_joystick_pos = Vector2(safe_left + 110.0, vp_size.y - safe_bottom - 110.0)
	if not _joystick_active:
		_joystick_center = _default_joystick_pos
		_joystick_current = _default_joystick_pos
	
	# Position Pause Button safely
	if pause_button:
		pause_button.position = Vector2(safe_left, safe_top)
		pause_button.size = Vector2(64, 64)
	
	queue_redraw()

func apply_default_layout() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	var safe_area: Rect2i = DisplayServer.get_display_safe_area()
	var window_size: Vector2i = DisplayServer.window_get_size()
	if window_size.x <= 0 or window_size.y <= 0:
		window_size = Vector2i(int(vp_size.x), int(vp_size.y))
	if safe_area.size.x <= 0 or safe_area.size.y <= 0:
		safe_area = Rect2i(Vector2i.ZERO, window_size)
	
	var scale_x: float = vp_size.x / float(window_size.x)
	var scale_y: float = vp_size.y / float(window_size.y)
	var safe_left: float = maxf(float(safe_area.position.x) * scale_x, 24.0)
	var safe_top: float = maxf(float(safe_area.position.y) * scale_y, 24.0)
	var safe_right: float = maxf(float(window_size.x - safe_area.end.x) * scale_x, 24.0)
	var safe_bottom: float = maxf(float(window_size.y - safe_area.end.y) * scale_y, 24.0)
	
	# 1. Left side
	if pause_button:
		pause_button.scale_factor = 1.0
		pause_button.position = Vector2(safe_left, safe_top)
	
	if left_fire_button:
		left_fire_button.scale_factor = 1.0
		left_fire_button.position = Vector2(safe_left + 40.0, vp_size.y - safe_bottom - 300.0)
	
	_default_joystick_pos = Vector2(safe_left + 110.0, vp_size.y - safe_bottom - 110.0)
	_joystick_center = _default_joystick_pos
	_joystick_current = _default_joystick_pos
	
	# 2. Right side middle: Main Fire & Combat
	var right_mid_y = vp_size.y * 0.48
	if fire_button:
		fire_button.scale_factor = 1.0
		fire_button.position = Vector2(vp_size.x - safe_right - 120.0, right_mid_y - 44.0)
	
	if block_button:
		block_button.scale_factor = 1.0
		block_button.position = Vector2(vp_size.x - safe_right - 206.0, right_mid_y - 54.0)
	
	if melee_button:
		melee_button.scale_factor = 1.0
		melee_button.position = Vector2(vp_size.x - safe_right - 206.0, right_mid_y + 28.0)
	
	if interact_button:
		interact_button.scale_factor = 1.0
		interact_button.position = Vector2(vp_size.x - safe_right - 296.0, right_mid_y - 130.0)
	
	# 3. Bottom-right cluster: Jump, Crouch, Reload
	if jump_button:
		jump_button.scale_factor = 1.0
		jump_button.position = Vector2(vp_size.x - safe_right - 104.0, vp_size.y - safe_bottom - 104.0)
	
	if crouch_button:
		crouch_button.scale_factor = 1.0
		crouch_button.position = Vector2(vp_size.x - safe_right - 192.0, vp_size.y - safe_bottom - 100.0)
	
	if reload_button:
		reload_button.scale_factor = 1.0
		reload_button.position = Vector2(vp_size.x - safe_right - 100.0, vp_size.y - safe_bottom - 192.0)
	
	_global_opacity = 1.0
	if buttons_container:
		buttons_container.modulate.a = 1.0
	
	queue_redraw()

# -----------------------------------------------------------------------------
# HUD CUSTOMIZATION (EDIT MODE)
# -----------------------------------------------------------------------------
func enter_edit_mode() -> void:
	_is_edit_mode = true
	visible = true
	set_process_input(true)
	set_process_unhandled_input(true)
	
	if edit_toolbar:
		edit_toolbar.visible = true
	
	for b in _get_all_buttons():
		b.visible = true
		b.is_selected_in_edit = false
	
	_selected_button = null
	if opacity_slider:
		opacity_slider.value = _global_opacity
	if opacity_value:
		opacity_value.text = "%d%%" % int(_global_opacity * 100.0)
	
	_select_button(fire_button)
	queue_redraw()

func exit_edit_mode() -> void:
	_is_edit_mode = false
	if edit_toolbar:
		edit_toolbar.visible = false
	
	for b in _get_all_buttons():
		b.is_selected_in_edit = false
	_selected_button = null
	
	# Hide interact button until an in-game prompt arrives
	if interact_button:
		interact_button.visible = false
	
	_update_visibility()
	queue_redraw()

func _select_button(btn: TouchButton) -> void:
	if _selected_button:
		_selected_button.is_selected_in_edit = false
		_selected_button.queue_redraw()
	
	_selected_button = btn
	if _selected_button:
		_selected_button.is_selected_in_edit = true
		_selected_button.queue_redraw()
		if scale_slider:
			scale_slider.value = _selected_button.scale_factor
		if scale_value:
			scale_value.text = "%.2fx" % _selected_button.scale_factor

func _handle_edit_input(event: InputEvent) -> void:
	var vp_size = get_viewport_rect().size
	
	if event is InputEventScreenTouch:
		if event.pressed:
			# Check if touching edit toolbar
			if edit_toolbar and edit_toolbar.get_global_rect().has_point(event.position):
				return
			
			# Find touched button
			for b in _get_all_buttons():
				if b and b.get_global_rect().has_point(event.position):
					_select_button(b)
					_edit_drag_touch_id = event.index
					_edit_drag_offset = event.position - b.global_position
					return
		else:
			if event.index == _edit_drag_touch_id:
				_edit_drag_touch_id = -1
	
	elif event is InputEventScreenDrag:
		if event.index == _edit_drag_touch_id and _selected_button:
			var target_pos = event.position - _edit_drag_offset
			target_pos.x = clampf(target_pos.x, 10.0, vp_size.x - _selected_button.size.x - 10.0)
			target_pos.y = clampf(target_pos.y, 10.0, vp_size.y - _selected_button.size.y - 10.0)
			_selected_button.global_position = target_pos
			queue_redraw()
	
	# Mouse support in edit mode (desktop preview)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if edit_toolbar and edit_toolbar.get_global_rect().has_point(event.position):
				return
			for b in _get_all_buttons():
				if b and b.get_global_rect().has_point(event.position):
					_select_button(b)
					_edit_drag_touch_id = 999
					_edit_drag_offset = event.position - b.global_position
					return
		else:
			_edit_drag_touch_id = -1
	
	elif event is InputEventMouseMotion and _edit_drag_touch_id == 999 and _selected_button:
		var target_pos = event.position - _edit_drag_offset
		target_pos.x = clampf(target_pos.x, 10.0, vp_size.x - _selected_button.size.x - 10.0)
		target_pos.y = clampf(target_pos.y, 10.0, vp_size.y - _selected_button.size.y - 10.0)
		_selected_button.global_position = target_pos
		queue_redraw()

func _on_scale_slider_changed(val: float) -> void:
	if _selected_button:
		_selected_button.set_scale_factor(val)
	if scale_value:
		scale_value.text = "%.2fx" % val

func _on_opacity_slider_changed(val: float) -> void:
	_global_opacity = val
	if buttons_container:
		buttons_container.modulate.a = val
	if opacity_value:
		opacity_value.text = "%d%%" % int(val * 100.0)

func _on_reset_layout_pressed() -> void:
	apply_default_layout()
	if _selected_button and scale_slider:
		scale_slider.value = _selected_button.scale_factor

func _on_save_exit_pressed() -> void:
	save_layout_for_aspect_ratio()
	exit_edit_mode()

# -----------------------------------------------------------------------------
# PERSISTENCE PER SCREEN ASPECT RATIO
# -----------------------------------------------------------------------------
func _get_aspect_ratio_key() -> String:
	var vp_size = get_viewport_rect().size
	var ratio = vp_size.x / maxf(vp_size.y, 1.0)
	if ratio >= 2.1:
		return "touch_layout_21_9"
	elif ratio >= 1.85:
		return "touch_layout_20_9"
	return "touch_layout_16_9"

func save_layout_for_aspect_ratio() -> void:
	var cfg = ConfigFile.new()
	cfg.load("user://settings.cfg")
	
	var section = _get_aspect_ratio_key()
	var vp_size = get_viewport_rect().size
	
	cfg.set_value(section, "global_opacity", _global_opacity)
	
	for b in _get_all_buttons():
		var b_name = b.name
		cfg.set_value(section, b_name + "_x_ratio", b.position.x / maxf(vp_size.x, 1.0))
		cfg.set_value(section, b_name + "_y_ratio", b.position.y / maxf(vp_size.y, 1.0))
		cfg.set_value(section, b_name + "_scale", b.scale_factor)
	
	cfg.save("user://settings.cfg")

func load_layout_for_aspect_ratio() -> void:
	var cfg = ConfigFile.new()
	var err = cfg.load("user://settings.cfg")
	if err != OK:
		apply_default_layout()
		return
	
	var section = _get_aspect_ratio_key()
	if not cfg.has_section(section):
		apply_default_layout()
		return
	
	var vp_size = get_viewport_rect().size
	_global_opacity = cfg.get_value(section, "global_opacity", 1.0)
	if buttons_container:
		buttons_container.modulate.a = _global_opacity
	
	for b in _get_all_buttons():
		var b_name = b.name
		var x_rat = cfg.get_value(section, b_name + "_x_ratio", -1.0)
		var y_rat = cfg.get_value(section, b_name + "_y_ratio", -1.0)
		var sc = cfg.get_value(section, b_name + "_scale", 1.0)
		
		if x_rat >= 0.0 and y_rat >= 0.0:
			b.set_scale_factor(sc)
			b.position = Vector2(x_rat * vp_size.x, y_rat * vp_size.y)
	
	queue_redraw()
