extends SceneTree

# Official Benchmark Script
# Adheres strictly to User Benchmark Protocol:
# - VSync OFF (DisplayServer.window_set_vsync_mode(0))
# - Fixed camera position & fixed look direction
# - Warmup 2.0s, Measurement 3.0s
# - Consistent FPS = 1000.0 / avg_ms
# - CPU vs GPU render time via RenderingServer
# - Draw calls and Objects in frame via Performance monitors
# - Compares:
#     1) High Quality (Procedural Triplanar Materials)
#     2) Low Quality (Cheap Non-Triplanar Materials)
#     3) Old Placeholder Materials

var vp: RID

var locations = [
	{
		"id": "corridor_start_north",
		"name": "Corridor Start (Facing North)",
		"pos": Vector3(4.5, 0.0, 7.9),
		"cam_pos": Vector3(4.5, 1.6, 7.9),
		"yaw": 0.0,
		"dir_desc": "North (0 deg, Vector(0, 0, -1))"
	},
	{
		"id": "corridor_start_east",
		"name": "Corridor Start (Facing East)",
		"pos": Vector3(4.5, 0.0, 7.9),
		"cam_pos": Vector3(4.5, 1.6, 7.9),
		"yaw": deg_to_rad(-90.0),
		"dir_desc": "East (-90 deg, Vector(1, 0, 0))"
	},
	{
		"id": "common_room",
		"name": "Common Room",
		"pos": Vector3(22.0, 0.0, 11.5),
		"cam_pos": Vector3(22.0, 1.6, 11.5),
		"yaw": deg_to_rad(-90.0),
		"dir_desc": "East (-90 deg, Vector(1, 0, 0))"
	},
	{
		"id": "stair_b",
		"name": "Stair B",
		"pos": Vector3(34.0, 0.0, 8.0),
		"cam_pos": Vector3(34.0, 1.6, 8.0),
		"yaw": deg_to_rad(-180.0),
		"dir_desc": "South (-180 deg, Vector(0, 0, 1))"
	},
	{
		"id": "apt_101",
		"name": "Apt 101 Inside",
		"pos": Vector3(8.0, 0.0, 3.5),
		"cam_pos": Vector3(8.0, 1.6, 3.5),
		"yaw": deg_to_rad(-90.0),
		"dir_desc": "East (-90 deg, Vector(1, 0, 0))"
	}
]

var _floor_inst: Node3D = null
var _player: Node3D = null

func _init() -> void:
	print("==========================================================================")
	print("STARTING OFFICIAL BENCHMARK PROTOCOL (VSYNC OFF, 2s WARMUP, 3s SAMPLE)")
	print("==========================================================================")
	call_deferred("_run_protocol")

func _run_protocol() -> void:
	DisplayServer.window_set_vsync_mode(0)
	vp = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	
	var floor_scene: PackedScene = load("res://game/scenes/gameplay/levels/Floor01.tscn")
	_floor_inst = floor_scene.instantiate() as Node3D
	root.add_child(_floor_inst)
	current_scene = _floor_inst
	
	_player = _floor_inst.find_child("Player", true, false)
	assert(_player != null, "Player must exist")
	
	# Enable god mode so gunfire does not kill player during benchmark runs
	var health_comp = _player.get_node_or_null("HealthComponent")
	if health_comp:
		health_comp.invulnerable = true
	
	var sm = root.get_node_or_null("SettingsManager")
	
	# 1. RUN HIGH QUALITY (Triplanar Noise Materials)
	if sm:
		sm.apply_graphics_quality("High")
	print("\n>>> MEASURING: HIGH QUALITY (PROCEDURAL TRIPLANAR NOISE) <<<")
	var results_high = await _measure_suite("High Quality (Triplanar)")
	
	# 2. RUN LOW QUALITY (Non-Triplanar Flat Materials)
	if sm:
		sm.apply_graphics_quality("Low")
	print("\n>>> MEASURING: LOW QUALITY (NON-TRIPLANAR FLAT MATERIALS) <<<")
	var results_low = await _measure_suite("Low Quality (Non-Triplanar)")
	
	# 3. RUN OLD PLACEHOLDERS (Baseline Comparison)
	print("\n>>> MEASURING: OLD PLACEHOLDER MATERIALS <<<")
	_swap_to_placeholder_materials(_floor_inst)
	var results_placeholder = await _measure_suite("Old Placeholders")
	
	_print_formatted_report(results_high, results_low, results_placeholder)
	quit(0)

func _measure_suite(suite_name: String) -> Array:
	var suite_results = []
	for loc in locations:
		if _player.has_method("teleport"):
			_player.teleport(loc.pos, loc.yaw, 0.0)
		else:
			_player.global_position = loc.pos
			_player.rotation.y = loc.yaw
			_player.reset_physics_interpolation()
			var pivot = _player.get_node_or_null("CameraPivot")
			if pivot:
				pivot.global_position = loc.pos + Vector3(0.0, 1.6, 0.0)
				pivot.rotation.x = 0.0
				pivot.reset_physics_interpolation()
		
		# 2.0s Warmup
		var warmup_t0 = Time.get_ticks_msec()
		while (Time.get_ticks_msec() - warmup_t0) < 2000:
			await process_frame
		
		# 3.0s Measurement Window
		var frames = 0
		var cpu_sum = 0.0
		var gpu_sum = 0.0
		var dc_sum = 0.0
		var obj_sum = 0.0
		
		var t_start_us = Time.get_ticks_usec()
		var t_start_ms = Time.get_ticks_msec()
		while (Time.get_ticks_msec() - t_start_ms) < 3000:
			await process_frame
			frames += 1
			cpu_sum += RenderingServer.viewport_get_measured_render_time_cpu(vp)
			gpu_sum += RenderingServer.viewport_get_measured_render_time_gpu(vp)
			dc_sum += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			obj_sum += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		
		var t_end_us = Time.get_ticks_usec()
		var total_sec = float(t_end_us - t_start_us) / 1000000.0
		var total_ms = total_sec * 1000.0
		
		var avg_ms = total_ms / float(frames)
		var fps = float(frames) / total_sec
		var avg_cpu = cpu_sum / float(frames)
		var avg_gpu = gpu_sum / float(frames)
		var avg_dc = int(round(dc_sum / float(frames)))
		var avg_obj = int(round(obj_sum / float(frames)))
		
		print("[%s] %-30s | FPS: %5.1f (%5.2f ms) | CPU: %5.2f ms | GPU: %5.2f ms | DC: %3d | Obj: %3d" % [
			suite_name, loc.name, fps, avg_ms, avg_cpu, avg_gpu, avg_dc, avg_obj
		])
		
		suite_results.append({
			"id": loc.id,
			"name": loc.name,
			"pos": loc.pos,
			"cam_pos": loc.cam_pos,
			"yaw": loc.yaw,
			"dir_desc": loc.dir_desc,
			"fps": fps,
			"avg_ms": avg_ms,
			"cpu_ms": avg_cpu,
			"gpu_ms": avg_gpu,
			"dc": avg_dc,
			"obj": avg_obj
		})
	return suite_results

func _print_formatted_report(res_high: Array, res_low: Array, res_place: Array) -> void:
	print("\n" + "=".repeat(120))
	print("BENCHMARK REPORT: BEFORE / AFTER & HIGH / LOW QUALITY (VSYNC OFF, 2s WARMUP, 3s SAMPLE)")
	print("=".repeat(120))
	print("%-30s | %-16s | %-18s | %-10s | %-10s | %-4s | %-4s" % [
		"Location & Look Direction", "Configuration", "FPS (Avg Frame ms)", "CPU Render", "GPU Render", "DC", "Obj"
	])
	print("-".repeat(120))
	for i in range(res_high.size()):
		var h = res_high[i]
		var l = res_low[i]
		var p = res_place[i]
		
		print("%-30s | %-16s | %5.1f (%5.2f ms) | %6.2f ms | %6.2f ms | %3d  | %3d" % [
			h.name, "High (Triplanar)", h.fps, h.avg_ms, h.cpu_ms, h.gpu_ms, h.dc, h.obj
		])
		print("%-30s | %-16s | %5.1f (%5.2f ms) | %6.2f ms | %6.2f ms | %3d  | %3d" % [
			"", "Low (Non-Triplan)", l.fps, l.avg_ms, l.cpu_ms, l.gpu_ms, l.dc, l.obj
		])
		print("%-30s | %-16s | %5.1f (%5.2f ms) | %6.2f ms | %6.2f ms | %3d  | %3d" % [
			"", "Old Placeholder", p.fps, p.avg_ms, p.cpu_ms, p.gpu_ms, p.dc, p.obj
		])
		print("-".repeat(120))
	print("=".repeat(120))

func _swap_to_placeholder_materials(node: Node) -> void:
	var mat_wall = load("res://game/assets/materials/placeholder/mat_wall.tres")
	var mat_floor = load("res://game/assets/materials/placeholder/mat_floor.tres")
	var mat_accent = load("res://game/assets/materials/placeholder/mat_accent.tres")
	_recursive_swap_material(node, mat_wall, mat_floor, mat_accent)

func _recursive_swap_material(node: Node, m_wall, m_floor, m_accent) -> void:
	if node is MeshInstance3D:
		var n_low = node.name.to_lower()
		var p_low = node.get_parent().name.to_lower() if node.get_parent() else ""
		if "floor" in n_low or "floor" in p_low:
			node.material_override = m_floor
		elif "barricade" in n_low or "barricade" in p_low or "accent" in n_low:
			node.material_override = m_accent
		else:
			node.material_override = m_wall
	for c in node.get_children():
		_recursive_swap_material(c, m_wall, m_floor, m_accent)
