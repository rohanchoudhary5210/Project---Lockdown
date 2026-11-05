class_name TouchButton
extends Control

## Project: Lockdown - Touch Button (PUBG Mobile Style Layout)
## Semi-transparent virtual button (>= 64px) for touch interfaces.
## Supports drag event forwarding (fire-and-drag), resizing (0.6x-1.5x), and edit mode selection.

signal button_pressed()
signal button_released()
signal touch_dragged(relative: Vector2, index: int)

@export var action_name: String = ""
@export var is_toggle_button: bool = false
@export var button_label_text: String = ""
@export var normal_color: Color = Color(0.12, 0.16, 0.22, 0.6)
@export var pressed_color: Color = Color(0.25, 0.65, 0.95, 0.85)
@export var border_color: Color = Color(0.3, 0.7, 1.0, 0.75)

var is_pressed: bool = false
var scale_factor: float = 1.0: set = set_scale_factor
var base_size: Vector2 = Vector2(68.0, 68.0)
var is_selected_in_edit: bool = false

var _touch_id: int = -1
var _toggle_state: bool = false
var _panel_style: StyleBoxFlat

func _ready() -> void:
	if custom_minimum_size.x <= 0 or custom_minimum_size.y <= 0:
		custom_minimum_size = Vector2(68.0, 68.0)
	base_size = Vector2(maxf(custom_minimum_size.x, 64.0), maxf(custom_minimum_size.y, 64.0))
	custom_minimum_size = base_size
	size = base_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	_panel_style = StyleBoxFlat.new()
	_update_style()
	queue_redraw()

func set_scale_factor(s: float) -> void:
	scale_factor = clampf(s, 0.6, 1.5)
	var new_w = maxf(base_size.x * scale_factor, 64.0)
	var new_h = maxf(base_size.y * scale_factor, 64.0)
	custom_minimum_size = Vector2(new_w, new_h)
	size = custom_minimum_size
	_update_style()
	queue_redraw()

func _update_style() -> void:
	if not _panel_style:
		_panel_style = StyleBoxFlat.new()
	var corner_radius = int(minf(size.x, size.y) * 0.5)
	_panel_style.corner_radius_top_left = corner_radius
	_panel_style.corner_radius_top_right = corner_radius
	_panel_style.corner_radius_bottom_right = corner_radius
	_panel_style.corner_radius_bottom_left = corner_radius
	_panel_style.border_width_left = 2
	_panel_style.border_width_top = 2
	_panel_style.border_width_right = 2
	_panel_style.border_width_bottom = 2
	_panel_style.border_color = border_color
	_panel_style.bg_color = normal_color

func _draw() -> void:
	var rect = Rect2(Vector2.ZERO, size)
	var corner_radius = int(minf(size.x, size.y) * 0.5)
	_panel_style.corner_radius_top_left = corner_radius
	_panel_style.corner_radius_top_right = corner_radius
	_panel_style.corner_radius_bottom_right = corner_radius
	_panel_style.corner_radius_bottom_left = corner_radius
	_panel_style.bg_color = pressed_color if is_pressed else normal_color
	_panel_style.draw(get_canvas_item(), rect)
	
	# Draw label
	if not button_label_text.is_empty():
		var font = ThemeDB.fallback_font
		var font_size = int(clampf(14.0 * scale_factor, 11.0, 20.0))
		var str_size = font.get_string_size(button_label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		var text_pos = Vector2((size.x - str_size.x) * 0.5, (size.y + str_size.y * 0.5) * 0.5)
		var text_col = Color.WHITE if not is_pressed else Color(1.0, 1.0, 0.9)
		draw_string(font, text_pos, button_label_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, text_col)
	
	# Draw edit mode selection highlight
	if is_selected_in_edit:
		var sel_col = Color(1.0, 0.85, 0.2, 0.9)
		draw_arc(rect.get_center(), maxf(size.x, size.y) * 0.5 + 4.0, 0, TAU, 32, sel_col, 2.5)

func _gui_input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	
	# Touch input
	if event is InputEventScreenTouch:
		if event.pressed and _touch_id == -1:
			_touch_id = event.index
			_press_button()
			accept_event()
		elif not event.pressed and event.index == _touch_id:
			_touch_id = -1
			_release_button()
			accept_event()
		return
	
	# Drag event (fire-and-drag support)
	if event is InputEventScreenDrag:
		if event.index == _touch_id:
			touch_dragged.emit(event.relative, event.index)
			accept_event()
		return
	
	# Mouse input (for desktop / debug testing)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and not is_pressed:
			_press_button()
			accept_event()
		elif not event.pressed and is_pressed:
			_release_button()
			accept_event()
		return
	
	if event is InputEventMouseMotion and is_pressed:
		touch_dragged.emit(event.relative, -1)
		accept_event()

func _press_button() -> void:
	if is_toggle_button:
		_toggle_state = not _toggle_state
		is_pressed = _toggle_state
		if is_pressed:
			if not action_name.is_empty():
				Input.action_press(action_name)
		else:
			if not action_name.is_empty():
				Input.action_release(action_name)
	else:
		is_pressed = true
		if not action_name.is_empty():
			Input.action_press(action_name)
	
	queue_redraw()
	button_pressed.emit()

func _release_button() -> void:
	if is_toggle_button:
		return
	
	is_pressed = false
	if not action_name.is_empty():
		Input.action_release(action_name)
	
	queue_redraw()
	button_released.emit()

func force_release() -> void:
	_touch_id = -1
	is_pressed = false
	_toggle_state = false
	if not action_name.is_empty():
		Input.action_release(action_name)
	queue_redraw()
