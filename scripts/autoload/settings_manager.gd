extends Node

## Project: Lockdown - Settings Manager (Milestone 9)
## Manages loading, saving, and immediate application of player configuration to user://settings.cfg.

signal settings_changed(key: String, value: Variant)

const SETTINGS_FILE: String = "user://settings.cfg"

var mouse_sensitivity: float = 0.002
var look_speed: float = 3.0
var invert_y: bool = false
var fov: float = 78.0
var crouch_toggle: bool = false
var touch_recoil: float = 0.45
var aim_assist: String = "Off" # "Off", "Low", "High"
const DEFAULT_TOUCH_SENS_H: float = 0.0025
const DEFAULT_TOUCH_SENS_V: float = 0.0020
const DEFAULT_TOUCH_SMOOTHING: float = 0.0 # raw: the camera follows the finger with no trailing
const TOUCH_TUNING_VERSION: int = 2 # bump to re-apply the touch defaults over older saved settings
var touch_sens_h: float = DEFAULT_TOUCH_SENS_H
var touch_sens_v: float = DEFAULT_TOUCH_SENS_V
var touch_smoothing: float = DEFAULT_TOUCH_SMOOTHING
var gyro_mode: int = 0 # 0 = Off, 1 = Always, 2 = While firing
var gyro_sensitivity: float = 1.0
var master_volume: float = 1.0
var show_ai_debug: bool = false
var touch_controls_mode: int = 0 # 0 = Auto, 1 = On (debug), 2 = Off
var graphics_quality: String = "High"

var _config: ConfigFile = ConfigFile.new()

func _get_default_graphics() -> String:
	if OS.get_name() == "Android" or OS.has_feature("android"):
		return "Low"
	return "High"

func _get_default_aim_assist() -> String:
	if should_show_touch_controls():
		return "High"
	var im = get_node_or_null("/root/InputManager")
	if im and "last_input_device" in im and im.last_input_device == im.InputDevice.GAMEPAD:
		return "Low"
	return "Off"

func _ready() -> void:
	graphics_quality = _get_default_graphics()
	aim_assist = _get_default_aim_assist()
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply_all_settings()

func load_settings() -> void:
	_config.clear() # load() merges into existing keys instead of replacing them
	var err = _config.load(SETTINGS_FILE)
	if err == OK:
		mouse_sensitivity = _config.get_value("controls", "mouse_sensitivity", 0.002)
		look_speed = _config.get_value("controls", "look_speed", 3.0)
		invert_y = _config.get_value("controls", "invert_y", false)
		crouch_toggle = _config.get_value("controls", "crouch_toggle", false)
		touch_controls_mode = _config.get_value("controls", "touch_controls_mode", 0)
		touch_recoil = _config.get_value("controls", "touch_recoil", 0.45)
		aim_assist = _config.get_value("controls", "aim_assist", _get_default_aim_assist())
		touch_sens_h = _config.get_value("controls", "touch_sens_h", DEFAULT_TOUCH_SENS_H)
		touch_sens_v = _config.get_value("controls", "touch_sens_v", DEFAULT_TOUCH_SENS_V)
		touch_smoothing = _config.get_value("controls", "touch_smoothing", DEFAULT_TOUCH_SMOOTHING)
		if int(_config.get_value("controls", "touch_tuning", 1)) < TOUCH_TUNING_VERSION:
			# Older saves kept the heavy defaults (smoothing 0.5, lower sensitivity); replace them once.
			touch_sens_h = DEFAULT_TOUCH_SENS_H
			touch_sens_v = DEFAULT_TOUCH_SENS_V
			touch_smoothing = DEFAULT_TOUCH_SMOOTHING
			save_settings()
		gyro_mode = _config.get_value("controls", "gyro_mode", 0)
		gyro_sensitivity = _config.get_value("controls", "gyro_sensitivity", 1.0)
		
		fov = _config.get_value("display", "fov", 78.0)
		graphics_quality = _config.get_value("display", "graphics_quality", _get_default_graphics())
		master_volume = _config.get_value("audio", "master_volume", 1.0)
		show_ai_debug = _config.get_value("debug", "show_ai_debug", false)
	else:
		save_settings()

func save_settings() -> void:
	_config.set_value("controls", "mouse_sensitivity", mouse_sensitivity)
	_config.set_value("controls", "look_speed", look_speed)
	_config.set_value("controls", "invert_y", invert_y)
	_config.set_value("controls", "crouch_toggle", crouch_toggle)
	_config.set_value("controls", "touch_controls_mode", touch_controls_mode)
	_config.set_value("controls", "touch_recoil", touch_recoil)
	_config.set_value("controls", "aim_assist", aim_assist)
	_config.set_value("controls", "touch_sens_h", touch_sens_h)
	_config.set_value("controls", "touch_sens_v", touch_sens_v)
	_config.set_value("controls", "touch_smoothing", touch_smoothing)
	_config.set_value("controls", "touch_tuning", TOUCH_TUNING_VERSION)
	_config.set_value("controls", "gyro_mode", gyro_mode)
	_config.set_value("controls", "gyro_sensitivity", gyro_sensitivity)
	
	_config.set_value("display", "fov", fov)
	_config.set_value("display", "graphics_quality", graphics_quality)
	_config.set_value("audio", "master_volume", master_volume)
	_config.set_value("debug", "show_ai_debug", show_ai_debug)
	_config.save(SETTINGS_FILE)

func set_setting(key: String, value: Variant, save_to_disk: bool = true) -> void:
	var old_val: Variant = null
	match key:
		"mouse_sensitivity":
			mouse_sensitivity = float(value)
		"look_speed":
			look_speed = float(value)
		"invert_y":
			invert_y = bool(value)
		"fov":
			fov = clampf(float(value), 70.0, 90.0)
		"graphics_quality":
			old_val = graphics_quality
			graphics_quality = str(value)
		"crouch_toggle":
			crouch_toggle = bool(value)
		"master_volume":
			master_volume = clampf(float(value), 0.0, 1.0)
		"show_ai_debug":
			show_ai_debug = bool(value)
		"touch_controls_mode":
			touch_controls_mode = int(value)
		"touch_recoil":
			touch_recoil = clampf(float(value), 0.25, 1.0)
		"aim_assist":
			aim_assist = str(value)
		"touch_sens_h":
			touch_sens_h = maxf(float(value), 0.0001)
		"touch_sens_v":
			touch_sens_v = maxf(float(value), 0.0001)
		"touch_smoothing":
			touch_smoothing = clampf(float(value), 0.0, 1.0)
		"gyro_mode":
			gyro_mode = int(value)
		"gyro_sensitivity":
			gyro_sensitivity = clampf(float(value), 0.2, 4.0)
	
	if save_to_disk:
		save_settings()
	
	apply_setting(key, value, old_val)
	settings_changed.emit(key, value)

func apply_setting(key: String, _val: Variant, old_val: Variant = null) -> void:
	var im = get_node_or_null("/root/InputManager")
	var players = get_tree().get_nodes_in_group("player") if get_tree() else []
	
	match key:
		"mouse_sensitivity":
			if im:
				im.mouse_sensitivity = mouse_sensitivity
			for p in players:
				if "player_data" in p and p.player_data:
					p.player_data.mouse_sensitivity = mouse_sensitivity
		"look_speed":
			if im:
				im.controller_look_speed = look_speed
			for p in players:
				if "player_data" in p and p.player_data:
					p.player_data.controller_look_speed = look_speed
		"invert_y":
			if im:
				im.invert_y = invert_y
			for p in players:
				if "player_data" in p and p.player_data:
					p.player_data.invert_y = invert_y
		"fov":
			for p in players:
				if "player_data" in p and p.player_data:
					p.player_data.default_fov = fov
				if "camera" in p and p.camera:
					p.camera.fov = fov
		"crouch_toggle":
			for p in players:
				if "player_data" in p and p.player_data:
					p.player_data.crouch_toggle_mode = crouch_toggle
		"graphics_quality":
			for p in players:
				if "player_data" in p and p.player_data:
					p.player_data.graphics_quality = graphics_quality
			# The material swap runs ONLY when graphics_quality actually changes!
			if old_val == null or str(old_val) != graphics_quality:
				apply_graphics_quality(graphics_quality)
		"master_volume":
			var master_bus_idx = AudioServer.get_bus_index("Master")
			if master_bus_idx >= 0:
				if master_volume <= 0.001:
					AudioServer.set_bus_mute(master_bus_idx, true)
				else:
					AudioServer.set_bus_mute(master_bus_idx, false)
					AudioServer.set_bus_volume_db(master_bus_idx, linear_to_db(master_volume))
		"show_ai_debug":
			if OS.is_debug_build():
				EnemyDebugOverlay.global_overlay_visible = show_ai_debug
				var dt = get_node_or_null("/root/DebugTools")
				if dt and dt.has_signal("ai_debug_overlay_toggled"):
					dt.ai_debug_overlay_toggled.emit(show_ai_debug)
		"aim_assist":
			for p in players:
				if "aim_assist_setting" in p:
					p.aim_assist_setting = aim_assist
		"touch_sens_h":
			if im and "touch_sens_h" in im:
				im.touch_sens_h = touch_sens_h
		"touch_sens_v":
			if im and "touch_sens_v" in im:
				im.touch_sens_v = touch_sens_v
		"touch_smoothing":
			if im and "touch_smoothing" in im:
				im.touch_smoothing = touch_smoothing
		"gyro_mode":
			if im and "gyro_mode" in im:
				im.gyro_mode = gyro_mode
		"gyro_sensitivity":
			if im and "gyro_sensitivity" in im:
				im.gyro_sensitivity = gyro_sensitivity

func apply_all_settings() -> void:
	# 1. Update InputManager
	var im = get_node_or_null("/root/InputManager")
	if im:
		im.mouse_sensitivity = mouse_sensitivity
		im.controller_look_speed = look_speed
		im.invert_y = invert_y
		if "touch_sens_h" in im:
			im.touch_sens_h = touch_sens_h
		if "touch_sens_v" in im:
			im.touch_sens_v = touch_sens_v
		if "touch_smoothing" in im:
			im.touch_smoothing = touch_smoothing
		if "gyro_mode" in im:
			im.gyro_mode = gyro_mode
		if "gyro_sensitivity" in im:
			im.gyro_sensitivity = gyro_sensitivity
	
	# 2. Update Master Volume
	var master_bus_idx = AudioServer.get_bus_index("Master")
	if master_bus_idx >= 0:
		if master_volume <= 0.001:
			AudioServer.set_bus_mute(master_bus_idx, true)
		else:
			AudioServer.set_bus_mute(master_bus_idx, false)
			AudioServer.set_bus_volume_db(master_bus_idx, linear_to_db(master_volume))
	
	# 3. Update Enemy AI Debug Overlay (if debug build)
	if OS.is_debug_build():
		EnemyDebugOverlay.global_overlay_visible = show_ai_debug
		var dt = get_node_or_null("/root/DebugTools")
		if dt and dt.has_signal("ai_debug_overlay_toggled"):
			dt.ai_debug_overlay_toggled.emit(show_ai_debug)
	
	# 4. Update Graphics Quality
	apply_graphics_quality(graphics_quality)
	
	# 5. Update Player instances in the scene
	var players = get_tree().get_nodes_in_group("player") if get_tree() else []
	for p in players:
		apply_to_player(p)

var _mats_high = {
	"concrete": preload("res://assets/procedural/materials/mat_concrete_wall.tres"),
	"plaster": preload("res://assets/procedural/materials/mat_plaster_wall.tres"),
	"floor": preload("res://assets/procedural/materials/mat_tiled_floor.tres"),
	"ceiling": preload("res://assets/procedural/materials/mat_ceiling.tres"),
	"metal": preload("res://assets/procedural/materials/mat_metal.tres"),
	"wood": preload("res://assets/procedural/materials/mat_wood.tres")
}

var _mats_low = {
	"concrete": preload("res://assets/procedural/materials/mat_concrete_wall_low.tres"),
	"plaster": preload("res://assets/procedural/materials/mat_plaster_wall_low.tres"),
	"floor": preload("res://assets/procedural/materials/mat_tiled_floor_low.tres"),
	"ceiling": preload("res://assets/procedural/materials/mat_ceiling_low.tres"),
	"metal": preload("res://assets/procedural/materials/mat_metal_low.tres"),
	"wood": preload("res://assets/procedural/materials/mat_wood_low.tres")
}

func apply_graphics_quality(quality: String) -> void:
	var vp = get_viewport()
	if not vp:
		return
	if quality == "Low":
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
		vp.scaling_3d_scale = 0.75
		vp.positional_shadow_atlas_size = 0
		vp.msaa_3d = Viewport.MSAA_DISABLED
		_apply_material_quality(true)
	else:
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
		vp.scaling_3d_scale = 1.0
		vp.positional_shadow_atlas_size = 4096
		vp.msaa_3d = Viewport.MSAA_DISABLED
		_apply_material_quality(false)

func _apply_material_quality(is_low: bool) -> void:
	var target_mats = _mats_low if is_low else _mats_high
	var root_node = get_tree().current_scene
	if not root_node:
		return
	_update_materials_recursive(root_node, target_mats, is_low)

func _update_materials_recursive(node: Node, target_mats: Dictionary, is_low: bool) -> void:
	if node is MeshInstance3D:
		# Do not overwrite weapon viewmodel materials (layer 2)
		if node.layers & 2 != 0:
			return
		var m = node.mesh
		# Safe check: only process PrimitiveMesh and ArrayMesh; skip ImmediateMesh (debug overlays) and meshes without geometry
		if m and (m is PrimitiveMesh or m is ArrayMesh):
			var base_mat: Material = null
			if node.material_override:
				base_mat = node.material_override
			elif m is PrimitiveMesh:
				base_mat = m.material
			elif m is ArrayMesh and m.get_surface_count() > 0:
				base_mat = node.get_surface_override_material(0)
				if not base_mat:
					base_mat = m.surface_get_material(0)
			
			if base_mat:
				var path = base_mat.resource_path
				if is_low:
					if "concrete_wall" in path:
						node.material_override = target_mats["concrete"]
					elif "plaster_wall" in path:
						node.material_override = target_mats["plaster"]
					elif "tiled_floor" in path:
						node.material_override = target_mats["floor"]
					elif "ceiling" in path:
						node.material_override = target_mats["ceiling"]
					elif path.ends_with("mat_metal.tres"):
						node.material_override = target_mats["metal"]
					elif "wood" in path:
						node.material_override = target_mats["wood"]
				else:
					# High quality: clear override if it was an applied low-quality override
					if node.material_override:
						var ov_path = node.material_override.resource_path
						if "_low.tres" in ov_path or "mat_" in ov_path:
							node.material_override = null
	
	for child in node.get_children():
		_update_materials_recursive(child, target_mats, is_low)

func apply_to_player(player: Node) -> void:
	if not player:
		return
	if "player_data" in player and player.player_data:
		player.player_data.mouse_sensitivity = mouse_sensitivity
		player.player_data.controller_look_speed = look_speed
		player.player_data.invert_y = invert_y
		player.player_data.default_fov = fov
		player.player_data.crouch_toggle_mode = crouch_toggle
		player.player_data.graphics_quality = graphics_quality
	
	if "camera" in player and player.camera:
		player.camera.fov = fov
	
	if "aim_assist_setting" in player:
		player.aim_assist_setting = aim_assist

func should_show_touch_controls() -> bool:
	if touch_controls_mode == 1:
		return true
	if touch_controls_mode == 2:
		return false
	return DisplayServer.is_touchscreen_available() or OS.has_feature("mobile") or OS.has_feature("touchscreen")
