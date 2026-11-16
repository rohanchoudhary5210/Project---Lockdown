extends SceneTree

# Diagnostic & Verification Benchmark Script
# Adheres strictly to User Benchmark Protocol:
# - VSync OFF
# - Warmup 2.0s, Measurement 3.0s
# - Consistent FPS = 1000.0 / avg_ms
# - CPU and GPU render times via RenderingServer
# - Draw calls and Objects in frame

var vp: RID

var locations = [
	{
		"name": "Corridor Start (Facing North)",
		"pos": Vector3(4.5, 0.0, 7.9),
		"yaw": 0.0,
		"dir_desc": "Facing North (0 deg, Vector(0, 0, -1)) at Corridor North wall"
	},
	{
		"name": "Corridor Start (Facing East)",
		"pos": Vector3(4.5, 0.0, 7.9),
		"yaw": deg_to_rad(-90.0),
		"dir_desc": "Facing East (-90 deg, Vector(1, 0, 0)) down main corridor"
	},
	{
		"name": "Common Room",
		"pos": Vector3(22.0, 0.0, 11.5),
		"yaw": deg_to_rad(-90.0),
		"dir_desc": "Facing East (-90 deg, Vector(1, 0, 0)) into Common Room"
	},
	{
		"name": "Stair B",
		"pos": Vector3(34.0, 0.0, 8.0),
		"yaw": deg_to_rad(-180.0),
		"dir_desc": "Facing South (-180 deg, Vector(0, 0, 1)) toward Stair B"
	},
	{
		"name": "Apt 101 Inside",
		"pos": Vector3(8.0, 0.0, 3.5),
		"yaw": deg_to_rad(-90.0),
		"dir_desc": "Facing East (-90 deg, Vector(1, 0, 0)) toward Apt 102 wall"
	}
]

var _floor_inst: Node3D = null
var _player: Node3D = null

func _init() -> void:
	print("=== Initializing Diagnostic Benchmark ===")
	call_deferred("_run_all")

func _run_all() -> void:
	DisplayServer.window_set_vsync_mode(0)
	vp = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	
	var floor_scene: PackedScene = load("res://game/scenes/gameplay/levels/Floor01.tscn")
	_floor_inst = floor_scene.instantiate() as Node3D
	root.add_child(_floor_inst)
	current_scene = _floor_inst
	
	_player = _floor_inst.find_child("Player", true, false)
	assert(_player != null, "Player must exist")
	
	# TEST SUITE A: Current Procedural Triplanar Materials
	print("\n>>> BENCHMARK SUITE A: PROCEDURAL TRIPLANAR NOISE MATERIALS (CURRENT) <<<")
	var results_a = await _benchmark_suite("Procedural Triplanar")
	
	# TEST SUITE B: Swapped Back to Old Placeholder Materials (flat color + roughness)
	print("\n>>> BENCHMARK SUITE B: SWAPPED TO OLD PLACEHOLDER MATERIALS <<<")
	_swap_to_placeholder_materials(_floor_inst)
	var results_b = await _benchmark_suite("Old Placeholders")
	
	print("\n=========================================================================================================")
	print("COMPARISON TABLE: PROCEDURAL MATERIALS vs OLD PLACEHOLDERS (SAME CAMERA)")
	print("=========================================================================================================")
	print("%-32s | %-18s | %-12s | %-10s | %-10s | %-8s | %-8s" % ["Location & Direction", "Materials", "FPS / ms", "CPU Render", "GPU Render", "DrawCalls", "Objects"])
	print("---------------------------------------------------------------------------------------------------------")
	for r in results_a:
		print("%-32s | %-18s | %5.1f / %5.2f ms | %6.2f ms   | %6.2f ms   | %5d     | %5d" % [
			r.name, "Triplanar (New)", r.fps, r.avg_ms, r.avg_cpu, r.avg_gpu, r.avg_dc, r.avg_obj
		])
	print("---------------------------------------------------------------------------------------------------------")
	for r in results_b:
		print("%-32s | %-18s | %5.1f / %5.2f ms | %6.2f ms   | %6.2f ms   | %5d     | %5d" % [
			r.name, "Placeholder (Old)", r.fps, r.avg_ms, r.avg_cpu, r.avg_gpu, r.avg_dc, r.avg_obj
		])
	print("=========================================================================================================\n")
	
	quit(0)

func _benchmark_suite(suite_name: String) -> Array:
	var results = []
	for loc in locations:
		print("--- Running %s at %s ---" % [suite_name, loc.name])
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
		
		# 1. Warmup for 2.0s
		var warmup_start = Time.get_ticks_msec()
		while (Time.get_ticks_msec() - warmup_start) < 2000:
			await process_frame
		
		# 2. Measurement for 3.0s
		var frames = 0
		var cpu_sum = 0.0
		var gpu_sum = 0.0
		var dc_sum = 0.0
		var obj_sum = 0.0
		
		var meas_start = Time.get_ticks_usec()
		var meas_start_ms = Time.get_ticks_msec()
		while (Time.get_ticks_msec() - meas_start_ms) < 3000:
			await process_frame
			frames += 1
			cpu_sum += RenderingServer.viewport_get_measured_render_time_cpu(vp)
			gpu_sum += RenderingServer.viewport_get_measured_render_time_gpu(vp)
			dc_sum += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			obj_sum += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
		
		var meas_end = Time.get_ticks_usec()
		var total_time_sec = float(meas_end - meas_start) / 1000000.0
		var total_time_ms = total_time_sec * 1000.0
		
		var avg_ms = total_time_ms / float(frames)
		var fps = float(frames) / total_time_sec # exact reciprocal: fps = 1000.0 / avg_ms
		var avg_cpu = cpu_sum / float(frames)
		var avg_gpu = gpu_sum / float(frames)
		var avg_dc = int(dc_sum / float(frames))
		var avg_obj = int(obj_sum / float(frames))
		
		print("  -> FPS=%.1f (%.2f ms) | CPU=%.2f ms | GPU=%.2f ms | DC=%d | Obj=%d" % [
			fps, avg_ms, avg_cpu, avg_gpu, avg_dc, avg_obj
		])
		
		results.append({
			"name": loc.name,
			"pos": loc.pos,
			"dir_desc": loc.dir_desc,
			"fps": fps,
			"avg_ms": avg_ms,
			"avg_cpu": avg_cpu,
			"avg_gpu": avg_gpu,
			"avg_dc": avg_dc,
			"avg_obj": avg_obj
		})
	
	return results

func _swap_to_placeholder_materials(node: Node) -> void:
	# Load old placeholder materials
	var mat_wall = load("res://game/assets/materials/placeholder/mat_wall.tres")
	var mat_floor = load("res://game/assets/materials/placeholder/mat_floor.tres")
	var mat_ceiling = load("res://assets/placeholder/mat_ceiling.tres")
	var mat_cover = load("res://assets/placeholder/mat_cover.tres")
	var mat_barricade = load("res://assets/placeholder/mat_barricade.tres")
	
	_recursive_swap_material(node, mat_wall, mat_floor, mat_ceiling, mat_cover, mat_barricade)

func _recursive_swap_material(node: Node, m_wall, m_floor, m_ceil, m_cov, m_bar) -> void:
	if node is MeshInstance3D:
		var n_low = node.name.to_lower()
		var p_low = node.get_parent().name.to_lower() if node.get_parent() else ""
		
		if "floor" in n_low or "floor" in p_low:
			node.material_override = m_floor
		elif "ceiling" in n_low or "ceiling" in p_low:
			node.material_override = m_ceil
		elif "barricade" in n_low or "barricade" in p_low:
			node.material_override = m_bar
		elif "cover" in n_low or "cover" in p_low or "box" in n_low or "box" in p_low:
			node.material_override = m_cov
		else:
			node.material_override = m_wall
	
	for c in node.get_children():
		_recursive_swap_material(c, m_wall, m_floor, m_ceil, m_cov, m_bar)
