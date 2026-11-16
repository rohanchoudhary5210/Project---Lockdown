class_name SettingsMenu
extends UIController

## Project: Lockdown - Settings Menu (Milestone 9)
## Allows tuning of sensitivity, look speed, FOV, crouch mode, volume, touch controls, and debug options.
## Changes apply immediately and are saved through SettingsManager.
## A UIManager panel: pushed by Home and the pause menu, Back pops it.

signal back_pressed()

@onready var sens_slider: HSlider = %SensSlider
@onready var sens_value: Label = %SensValue
@onready var look_slider: HSlider = %LookSlider
@onready var look_value: Label = %LookValue
@onready var invert_y_check: CheckButton = %InvertYCheck
@onready var haptics_check: CheckButton = %HapticsCheck
@onready var fov_slider: HSlider = %FOVSlider
@onready var fov_value: Label = %FOVValue
@onready var crouch_check: CheckButton = %CrouchCheck
@onready var volume_slider: HSlider = %VolumeSlider
@onready var volume_value: Label = %VolumeValue
@onready var graphics_option: OptionButton = %GraphicsOption
@onready var touch_option: OptionButton = %TouchOption
@onready var touch_recoil_slider: HSlider = %TouchRecoilSlider
@onready var touch_recoil_value: Label = %TouchRecoilValue
@onready var aim_assist_option: OptionButton = %AimAssistOption
@onready var touch_sens_h_slider: HSlider = %TouchSensHSlider
@onready var touch_sens_h_value: Label = %TouchSensHValue
@onready var touch_sens_v_slider: HSlider = %TouchSensVSlider
@onready var touch_sens_v_value: Label = %TouchSensVValue
@onready var touch_smoothing_slider: HSlider = %TouchSmoothingSlider
@onready var touch_smoothing_value: Label = %TouchSmoothingValue
@onready var gyro_option: OptionButton = %GyroOption
@onready var gyro_sens_slider: HSlider = %GyroSensSlider
@onready var gyro_sens_value: Label = %GyroSensValue
@onready var customize_controls_button: Button = %CustomizeControlsButton
@onready var debug_row: HBoxContainer = %DebugRow
@onready var debug_check: CheckButton = %DebugCheck
@onready var back_button: Button = %BackButton

var _is_updating: bool = false

## Services come from GameService (see GameService._inject_into_new_nodes); null when run without it.
var _settings: SettingsManager

func inject_services(registry: Node) -> void:
	super.inject_services(registry)
	_settings = registry.get_service(&"settings") as SettingsManager

func _on_ready() -> void:
	_setup_graphics_options()
	_setup_touch_options()
	_setup_aim_assist_options()
	_setup_gyro_options()
	_connect_signals()
	refresh_values()

func _setup_graphics_options() -> void:
	if graphics_option:
		graphics_option.clear()
		graphics_option.add_item("High (Full Res, Shadows)", 0)
		graphics_option.add_item("Low (FSR 0.75x, No Shadows)", 1)

func _setup_touch_options() -> void:
	if touch_option:
		touch_option.clear()
		touch_option.add_item("Auto (Touchscreen Detect)", 0)
		touch_option.add_item("Always On (Touch / Debug)", 1)
		touch_option.add_item("Off", 2)

func _setup_aim_assist_options() -> void:
	if aim_assist_option:
		aim_assist_option.clear()
		aim_assist_option.add_item("Off", 0)
		aim_assist_option.add_item("Low", 1)
		aim_assist_option.add_item("High", 2)

func _setup_gyro_options() -> void:
	if gyro_option:
		gyro_option.clear()
		gyro_option.add_item("Off", 0)
		gyro_option.add_item("Always", 1)
		gyro_option.add_item("While firing", 2)

func _connect_signals() -> void:
	if sens_slider:
		sens_slider.value_changed.connect(_on_sens_changed)
		sens_slider.drag_ended.connect(_on_slider_drag_ended)
	if look_slider:
		look_slider.value_changed.connect(_on_look_changed)
		look_slider.drag_ended.connect(_on_slider_drag_ended)
	if invert_y_check:
		invert_y_check.toggled.connect(_on_invert_y_toggled)
	if haptics_check:
		haptics_check.toggled.connect(_on_haptics_toggled)
	if fov_slider:
		fov_slider.value_changed.connect(_on_fov_changed)
		fov_slider.drag_ended.connect(_on_slider_drag_ended)
	if crouch_check:
		crouch_check.toggled.connect(_on_crouch_toggled)
	if volume_slider:
		volume_slider.value_changed.connect(_on_volume_changed)
		volume_slider.drag_ended.connect(_on_slider_drag_ended)
	if graphics_option:
		graphics_option.item_selected.connect(_on_graphics_selected)
	if touch_option:
		touch_option.item_selected.connect(_on_touch_selected)
	if touch_recoil_slider:
		touch_recoil_slider.value_changed.connect(_on_touch_recoil_changed)
		touch_recoil_slider.drag_ended.connect(_on_slider_drag_ended)
	if aim_assist_option:
		aim_assist_option.item_selected.connect(_on_aim_assist_selected)
	if touch_sens_h_slider:
		touch_sens_h_slider.value_changed.connect(_on_touch_sens_h_changed)
		touch_sens_h_slider.drag_ended.connect(_on_slider_drag_ended)
	if touch_sens_v_slider:
		touch_sens_v_slider.value_changed.connect(_on_touch_sens_v_changed)
		touch_sens_v_slider.drag_ended.connect(_on_slider_drag_ended)
	if touch_smoothing_slider:
		touch_smoothing_slider.value_changed.connect(_on_touch_smoothing_changed)
		touch_smoothing_slider.drag_ended.connect(_on_slider_drag_ended)
	if gyro_option:
		gyro_option.item_selected.connect(_on_gyro_selected)
	if gyro_sens_slider:
		gyro_sens_slider.value_changed.connect(_on_gyro_sens_changed)
		gyro_sens_slider.drag_ended.connect(_on_slider_drag_ended)
	if customize_controls_button:
		customize_controls_button.pressed.connect(_on_customize_controls_pressed)
	if debug_check:
		debug_check.toggled.connect(_on_debug_toggled)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)

func _on_slider_drag_ended(_val_changed: bool) -> void:
	var sm = _settings
	if sm:
		sm.save_settings()

func _exit_tree() -> void:
	var sm = _settings
	if sm:
		sm.save_settings()

func refresh_values() -> void:
	var sm = _settings
	if not sm:
		return
	
	_is_updating = true
	
	if sens_slider:
		sens_slider.min_value = 0.0005
		sens_slider.max_value = 0.0060
		sens_slider.step = 0.0001
		sens_slider.value = sm.mouse_sensitivity
		if sens_value:
			sens_value.text = "%.4f" % sm.mouse_sensitivity
	
	if look_slider:
		look_slider.min_value = 0.5
		look_slider.max_value = 8.0
		look_slider.step = 0.1
		look_slider.value = sm.look_speed
		if look_value:
			look_value.text = "%.1f" % sm.look_speed
	
	if invert_y_check:
		invert_y_check.button_pressed = sm.invert_y
	if haptics_check:
		haptics_check.button_pressed = sm.haptics
	
	if fov_slider:
		fov_slider.min_value = 70.0
		fov_slider.max_value = 90.0
		fov_slider.step = 1.0
		fov_slider.value = sm.fov
		if fov_value:
			fov_value.text = "%d°" % int(sm.fov)
	
	if crouch_check:
		crouch_check.button_pressed = sm.crouch_toggle
	
	if volume_slider:
		volume_slider.min_value = 0.0
		volume_slider.max_value = 100.0
		volume_slider.step = 1.0
		volume_slider.value = sm.master_volume * 100.0
		if volume_value:
			volume_value.text = "%d%%" % int(sm.master_volume * 100.0)
	
	if graphics_option:
		var q_idx = 1 if sm.graphics_quality == "Low" else 0
		graphics_option.select(q_idx)
	
	if touch_option:
		touch_option.select(sm.touch_controls_mode)
	
	if touch_recoil_slider:
		touch_recoil_slider.min_value = 0.25
		touch_recoil_slider.max_value = 1.0
		touch_recoil_slider.step = 0.05
		touch_recoil_slider.value = sm.touch_recoil
		if touch_recoil_value:
			touch_recoil_value.text = "%.2f" % sm.touch_recoil
	
	if aim_assist_option:
		var aa_idx: int = 0
		if sm.aim_assist == "Low":
			aa_idx = 1
		elif sm.aim_assist == "High":
			aa_idx = 2
		aim_assist_option.select(aa_idx)
	
	if touch_sens_h_slider:
		touch_sens_h_slider.min_value = 0.0005
		touch_sens_h_slider.max_value = 0.0060
		touch_sens_h_slider.step = 0.0001
		touch_sens_h_slider.value = sm.touch_sens_h
		if touch_sens_h_value:
			touch_sens_h_value.text = "%.4f" % sm.touch_sens_h
	
	if touch_sens_v_slider:
		touch_sens_v_slider.min_value = 0.0005
		touch_sens_v_slider.max_value = 0.0060
		touch_sens_v_slider.step = 0.0001
		touch_sens_v_slider.value = sm.touch_sens_v
		if touch_sens_v_value:
			touch_sens_v_value.text = "%.4f" % sm.touch_sens_v
	
	if touch_smoothing_slider:
		touch_smoothing_slider.min_value = 0.0
		touch_smoothing_slider.max_value = 1.0
		touch_smoothing_slider.step = 0.05
		touch_smoothing_slider.value = sm.touch_smoothing
		if touch_smoothing_value:
			touch_smoothing_value.text = "%.2f" % sm.touch_smoothing
	
	if gyro_option:
		gyro_option.select(sm.gyro_mode)
	
	if gyro_sens_slider:
		gyro_sens_slider.min_value = 0.2
		gyro_sens_slider.max_value = 4.0
		gyro_sens_slider.step = 0.1
		gyro_sens_slider.value = sm.gyro_sensitivity
		if gyro_sens_value:
			gyro_sens_value.text = "%.1fx" % sm.gyro_sensitivity
	
	if debug_row:
		debug_row.visible = OS.is_debug_build()
	if debug_check:
		debug_check.button_pressed = sm.show_ai_debug
	
	_is_updating = false

func focus_first() -> void:
	if back_button:
		back_button.grab_focus()

func _on_sens_changed(val: float) -> void:
	if _is_updating:
		return
	if sens_value:
		sens_value.text = "%.4f" % val
	var sm = _settings
	if sm:
		sm.set_setting("mouse_sensitivity", val, false)

func _on_look_changed(val: float) -> void:
	if _is_updating:
		return
	if look_value:
		look_value.text = "%.1f" % val
	var sm = _settings
	if sm:
		sm.set_setting("look_speed", val, false)

func _on_invert_y_toggled(pressed: bool) -> void:
	if _is_updating:
		return
	var sm = _settings
	if sm:
		sm.set_setting("invert_y", pressed, true)

func _on_fov_changed(val: float) -> void:
	if _is_updating:
		return
	if fov_value:
		fov_value.text = "%d°" % int(val)
	var sm = _settings
	if sm:
		sm.set_setting("fov", val, false)

func _on_haptics_toggled(pressed: bool) -> void:
	if _is_updating:
		return
	var sm = _settings
	if sm:
		sm.set_setting("haptics", pressed, true)
		if pressed:
			sm.vibrate(40, 0.6) # so the player feels what they just turned on

func _on_crouch_toggled(pressed: bool) -> void:
	if _is_updating:
		return
	var sm = _settings
	if sm:
		sm.set_setting("crouch_toggle", pressed, true)

func _on_volume_changed(val: float) -> void:
	if _is_updating:
		return
	if volume_value:
		volume_value.text = "%d%%" % int(val)
	var sm = _settings
	if sm:
		sm.set_setting("master_volume", val / 100.0, false)

func _on_graphics_selected(idx: int) -> void:
	if _is_updating:
		return
	var sm = _settings
	if sm:
		var q = "Low" if idx == 1 else "High"
		sm.set_setting("graphics_quality", q, true)

func _on_touch_selected(idx: int) -> void:
	if _is_updating:
		return
	var sm = _settings
	if sm:
		sm.set_setting("touch_controls_mode", idx, true)

func _on_touch_recoil_changed(val: float) -> void:
	if _is_updating:
		return
	if touch_recoil_value:
		touch_recoil_value.text = "%.2f" % val
	var sm = _settings
	if sm:
		sm.set_setting("touch_recoil", val, false)

func _on_aim_assist_selected(idx: int) -> void:
	if _is_updating:
		return
	var sm = _settings
	if sm:
		var mode = "Off"
		if idx == 1:
			mode = "Low"
		elif idx == 2:
			mode = "High"
		sm.set_setting("aim_assist", mode, true)

func _on_touch_sens_h_changed(val: float) -> void:
	if _is_updating:
		return
	if touch_sens_h_value:
		touch_sens_h_value.text = "%.4f" % val
	var sm = _settings
	if sm:
		sm.set_setting("touch_sens_h", val, false)

func _on_touch_sens_v_changed(val: float) -> void:
	if _is_updating:
		return
	if touch_sens_v_value:
		touch_sens_v_value.text = "%.4f" % val
	var sm = _settings
	if sm:
		sm.set_setting("touch_sens_v", val, false)

func _on_touch_smoothing_changed(val: float) -> void:
	if _is_updating:
		return
	if touch_smoothing_value:
		touch_smoothing_value.text = "%.2f" % val
	var sm = _settings
	if sm:
		sm.set_setting("touch_smoothing", val, false)

func _on_gyro_selected(idx: int) -> void:
	if _is_updating:
		return
	var sm = _settings
	if sm:
		sm.set_setting("gyro_mode", idx, true)

func _on_gyro_sens_changed(val: float) -> void:
	if _is_updating:
		return
	if gyro_sens_value:
		gyro_sens_value.text = "%.1fx" % val
	var sm = _settings
	if sm:
		sm.set_setting("gyro_sensitivity", val, false)

func _on_customize_controls_pressed() -> void:
	var hud = get_tree().root.find_child("HUD", true, false)
	if hud:
		var tc = hud.find_child("TouchControls", true, false)
		if tc and tc.has_method("enter_edit_mode"):
			# Close the pause/settings panels while editing; the game stays paused until resumed
			_ui_manager.pop_to_root()
			_ui_manager.pop()
			tc.enter_edit_mode()

func _on_debug_toggled(pressed: bool) -> void:
	if _is_updating:
		return
	var sm = _settings
	if sm:
		sm.set_setting("show_ai_debug", pressed, true)

func _on_back_pressed() -> void:
	var sm = _settings
	if sm:
		sm.save_settings()
	back_pressed.emit()
	if _ui_manager and _ui_manager.current() == self:
		close()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("pause"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()
