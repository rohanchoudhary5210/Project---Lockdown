extends Node

## DebugTools Autoload
## Active only in debug builds.
## F1: Player takes 10 damage
## F2: Refill ammunition to max capacity
## F3: Toggle God Mode (invulnerability)
## F4: Toggle Enemy AI Debug Overlay (state name, vision cone, detection meter, last known pos)
## F5: Toggle Performance Overlay (FPS, frame time, draw calls)

signal ai_debug_overlay_toggled(is_visible: bool)
signal perf_overlay_toggled(is_visible: bool)

var perf_overlay_visible: bool = false

var _perf_canvas: CanvasLayer = null
var _perf_label: Label = null
var _perf_accum_time: float = 0.0
var _perf_accum_frames: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_perf_overlay()

func _create_perf_overlay() -> void:
	_perf_canvas = CanvasLayer.new()
	_perf_canvas.layer = 120
	_perf_canvas.visible = false
	add_child(_perf_canvas)
	
	var panel = PanelContainer.new()
	panel.position = Vector2(16, 16)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_perf_canvas.add_child(panel)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.85)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.2, 0.7, 0.4, 0.8)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_right = 4
	style.corner_radius_bottom_left = 4
	panel.add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)
	
	_perf_label = Label.new()
	_perf_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_perf_label.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5))
	_perf_label.add_theme_font_size_override("font_size", 14)
	_perf_label.text = "FPS: -- | Frame: -- ms | Draw Calls: -- | Objects: --"
	margin.add_child(_perf_label)

func _process(delta: float) -> void:
	if not perf_overlay_visible or not _perf_label:
		return
	
	_perf_accum_time += delta
	_perf_accum_frames += 1
	if _perf_accum_time >= 0.2: # Update ~5 times per second for smooth readability
		var avg_frame_ms: float = (_perf_accum_time / float(_perf_accum_frames)) * 1000.0
		var avg_fps: float = float(_perf_accum_frames) / _perf_accum_time
		var draw_calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		var objects: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
		_perf_label.text = "FPS: %d | Frame: %.2f ms | Draw Calls: %d | Objects: %d" % [int(round(avg_fps)), avg_frame_ms, draw_calls, objects]
		_perf_accum_time = 0.0
		_perf_accum_frames = 0

func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	
	if event is InputEventKey and event.pressed and not event.echo:
		var code = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		match code:
			KEY_F1:
				_debug_damage_player(10.0)
			KEY_F2:
				_debug_refill_ammo()
			KEY_F3:
				_debug_toggle_god_mode()
			KEY_F4:
				_debug_toggle_ai_overlay()
			KEY_F5:
				_debug_toggle_perf_overlay()

func _debug_toggle_perf_overlay() -> void:
	perf_overlay_visible = not perf_overlay_visible
	if _perf_canvas:
		_perf_canvas.visible = perf_overlay_visible
	_perf_accum_time = 0.0
	_perf_accum_frames = 0
	perf_overlay_toggled.emit(perf_overlay_visible)
	print("[DEBUG] F5 Pressed: Performance Overlay toggled: ", perf_overlay_visible)

func _debug_toggle_ai_overlay() -> void:
	EnemyDebugOverlay.global_overlay_visible = not EnemyDebugOverlay.global_overlay_visible
	ai_debug_overlay_toggled.emit(EnemyDebugOverlay.global_overlay_visible)
	print("[DEBUG] F4 Pressed: Enemy AI Debug Overlay toggled: ", EnemyDebugOverlay.global_overlay_visible)

func _debug_damage_player(amount: float) -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player and player.has_method("take_damage"):
		player.take_damage(amount)
		if player.health_component:
			print("[DEBUG] F1 Pressed: Player took %d damage. Current HP: %d" % [int(amount), int(player.health_component.current_health)])

func _debug_refill_ammo() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player:
		var weapon: Node = player.find_child("Pistol", true, false)
		if weapon and weapon.has_method("refill_ammo"):
			weapon.refill_ammo()
			print("[DEBUG] F2 Pressed: Ammunition refilled to maximum capacity (%d / %d)" % [weapon.current_ammo, weapon.reserve_ammo])

func _debug_toggle_god_mode() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player and player.health_component:
		player.health_component.invulnerable = not player.health_component.invulnerable
		print("[DEBUG] F3 Pressed: God Mode set to %s" % str(player.health_component.invulnerable))
