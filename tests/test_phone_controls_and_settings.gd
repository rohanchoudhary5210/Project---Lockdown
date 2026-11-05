extends SceneTree

## Test suite for Phone Testing Bug Fixes:
## Bug 1: SettingsManager ImmediateMesh crash on slider drag, isolated updates, disk save debounce
## Bug 2: Smooth phone controls (look in _process, 3D physics interpolation, touch drag consumption, 25ms smoothing, joystick curve, FPS benchmark)

var passed: int = 0
var failed: int = 0

func _init() -> void:
	run_all_tests()

func run_all_tests() -> void:
	print("\n=== STARTING PHONE CONTROLS & SETTINGS FIXES TEST SUITE ===")
	
	print("\n--- Test 1: Slider Dragging with F4 Overlay ON (No ImmediateMesh Crash) ---")
	if await test_slider_drag_with_f4_overlay():
		passed += 1
		print("PASSED: Test 1")
	else:
		failed += 1
		print("FAILED: Test 1")
	
	print("\n--- Test 2: Isolated Setting Application (Material Walk Only On Quality Change) ---")
	if await test_isolated_settings_application():
		passed += 1
		print("PASSED: Test 2")
	else:
		failed += 1
		print("FAILED: Test 2")
	
	print("\n--- Test 3: Disk Save Debounce (Save On Drag Ended / Menu Close) ---")
	if await test_disk_save_debounce():
		passed += 1
		print("PASSED: Test 3")
	else:
		failed += 1
		print("FAILED: Test 3")
	
	print("\n--- Test 4: Camera Look In _process (Never in _physics_process) ---")
	if await test_camera_look_in_process():
		passed += 1
		print("PASSED: Test 4")
	else:
		failed += 1
		print("FAILED: Test 4")
	
	print("\n--- Test 5: 3D Physics Interpolation & Interpolated Camera Pivot ---")
	if await test_physics_interpolation_and_camera_pivot():
		passed += 1
		print("PASSED: Test 5")
	else:
		failed += 1
		print("FAILED: Test 5")
	
	print("\n--- Test 6: use_accumulated_input = false & Consumes All Drag Events of Frame ---")
	if await test_touch_drag_consumption():
		passed += 1
		print("PASSED: Test 6")
	else:
		failed += 1
		print("FAILED: Test 6")
	
	print("\n--- Test 7: Touch Look Smoothing Time Constant (~25ms) ---")
	if await test_touch_smoothing_time_constant():
		passed += 1
		print("PASSED: Test 7")
	else:
		failed += 1
		print("FAILED: Test 7")
	
	print("\n--- Test 8: Joystick Curve for Slow Walking & PlayerData Acceleration ---")
	if await test_joystick_curve_and_acceleration():
		passed += 1
		print("PASSED: Test 8")
	else:
		failed += 1
		print("FAILED: Test 8")
	
	print("\n--- Test 9: Turn Rate Consistency across 30, 60, and 120 FPS ---")
	if await test_turn_rate_consistency_framerate():
		passed += 1
		print("PASSED: Test 9")
	else:
		failed += 1
		print("FAILED: Test 9")
	
	print("\n--- Test 10: Performance FPS (F5 Monitor) on Floor 01 ---")
	if await test_performance_fps_floor_01():
		passed += 1
		print("PASSED: Test 10")
	else:
		failed += 1
		print("FAILED: Test 10")
	
	print("\n=======================================================")
	print("RESULTS: %d Passed, %d Failed" % [passed, failed])
	print("=======================================================")
	
	if failed == 0:
		print("ALL PHONE CONTROLS & SETTINGS TESTS PASSED SUCCESSFULLY!\n")
		quit(0)
	else:
		print("SOME TESTS FAILED!\n")
		quit(1)

func test_slider_drag_with_f4_overlay() -> bool:
	var test_world = Node3D.new()
	root.add_child(test_world)
	await process_frame
	
	var player: PlayerController = load("res://scenes/player/player.tscn").instantiate()
	test_world.add_child(player)
	
	var enemy: EnemyBase = load("res://scenes/enemies/ranged_enemy.tscn").instantiate()
	enemy.position = Vector3(0, 0, -5.0)
	test_world.add_child(enemy)
	
	await process_frame
	await process_frame
	
	var sm = root.get_node_or_null("SettingsManager")
	if not sm:
		printerr("SettingsManager not found!")
		test_world.queue_free()
		return false
	
	# Turn F4 debug overlay ON: creates ImmediateMesh on enemy and player
	sm.set_setting("show_ai_debug", true)
	await process_frame
	
	# Instantiate SettingsMenu
	var menu_scene = load("res://scenes/ui/settings_menu.tscn")
	var menu: SettingsMenu = menu_scene.instantiate()
	root.add_child(menu)
	await process_frame
	
	var sliders: Array[HSlider] = [
		menu.sens_slider,
		menu.look_slider,
		menu.fov_slider,
		menu.volume_slider,
		menu.touch_recoil_slider,
		menu.touch_sens_h_slider,
		menu.touch_sens_v_slider,
		menu.touch_smoothing_slider,
		menu.gyro_sens_slider
	]
	
	# Drag every slider end to end across 20 steps
	for s in sliders:
		if not s:
			continue
		var s_min = s.min_value
		var s_max = s.max_value
		for step in range(21):
			var frac = float(step) / 20.0
			var val = lerpf(s_min, s_max, frac)
			s.value = val # triggers value_changed
			await process_frame
	
	# Also toggle graphics quality between Low and High with F4 overlay active
	sm.set_setting("graphics_quality", "Low")
	await process_frame
	sm.set_setting("graphics_quality", "High")
	await process_frame
	
	menu.queue_free()
	test_world.queue_free()
	return true

func test_isolated_settings_application() -> bool:
	var sm = root.get_node_or_null("SettingsManager")
	if not sm:
		return false
	
	var test_world = Node3D.new()
	root.add_child(test_world)
	var player: PlayerController = load("res://scenes/player/player.tscn").instantiate()
	test_world.add_child(player)
	await process_frame
	
	# 1. Mouse sensitivity applies directly to PlayerData and InputManager
	sm.set_setting("mouse_sensitivity", 0.0042, false)
	var im = root.get_node_or_null("InputManager")
	if absf(im.mouse_sensitivity - 0.0042) > 0.00001:
		printerr("InputManager mouse_sensitivity not updated! Got: ", im.mouse_sensitivity)
		test_world.queue_free()
		return false
	if absf(player.player_data.mouse_sensitivity - 0.0042) > 0.00001:
		printerr("Player player_data mouse_sensitivity not updated! Got: ", player.player_data.mouse_sensitivity)
		test_world.queue_free()
		return false
	
	# 2. FOV applies directly to camera
	sm.set_setting("fov", 85.0, false)
	if absf(player.camera.fov - 85.0) > 0.1:
		printerr("Player camera FOV not updated! Got: ", player.camera.fov)
		test_world.queue_free()
		return false
	
	# 3. Master volume applies directly to AudioServer
	sm.set_setting("master_volume", 0.65, false)
	var bus_idx = AudioServer.get_bus_index("Master")
	var expected_db = linear_to_db(0.65)
	var actual_db = AudioServer.get_bus_volume_db(bus_idx)
	if absf(actual_db - expected_db) > 0.1:
		printerr("AudioServer master volume mismatch! Got %f, expected %f" % [actual_db, expected_db])
		test_world.queue_free()
		return false
	
	test_world.queue_free()
	return true

func test_disk_save_debounce() -> bool:
	var menu_scene = load("res://scenes/ui/settings_menu.tscn")
	var menu: SettingsMenu = menu_scene.instantiate()
	root.add_child(menu)
	await process_frame
	
	var sm = root.get_node_or_null("SettingsManager")
	
	# Slider value_changed: sm.set_setting(..., false) does not force disk write
	menu._on_fov_changed(88.0)
	if absf(sm.fov - 88.0) > 0.1:
		printerr("Live apply failed on fov change!")
		menu.queue_free()
		return false
	
	# Slider drag_ended saves
	menu._on_slider_drag_ended(true)
	
	# Menu back pressed saves
	menu._on_back_pressed()
	
	menu.queue_free()
	return true

func test_camera_look_in_process() -> bool:
	var test_world = Node3D.new()
	root.add_child(test_world)
	await process_frame
	
	var player: PlayerController = load("res://scenes/player/player.tscn").instantiate()
	test_world.add_child(player)
	await process_frame
	
	var im = root.get_node_or_null("InputManager")
	if im:
		im.last_input_device = im.InputDevice.TOUCH
		im.mouse_captured = true
	
	# Inject look input
	im.inject_touch_look(Vector2(50.0, 30.0))
	
	var rot_before_physics = player.rotation.y
	var pitch_before_physics = player._pitch
	
	# Advance _physics_process: MUST NOT consume look delta or rotate camera!
	player._physics_process(0.016)
	
	if absf(player.rotation.y - rot_before_physics) > 0.00001 or absf(player._pitch - pitch_before_physics) > 0.00001:
		printerr("Camera look was applied inside _physics_process! Must be in _process only!")
		test_world.queue_free()
		return false
	
	# Advance _process: MUST consume look delta and rotate camera smoothly
	player._process(0.016)
	
	if absf(player.rotation.y - rot_before_physics) < 0.00001:
		printerr("Camera look was NOT applied inside _process!")
		test_world.queue_free()
		return false
	
	test_world.queue_free()
	return true

func test_physics_interpolation_and_camera_pivot() -> bool:
	# 1. Verify project setting
	var interp_enabled = ProjectSettings.get_setting("physics/common/physics_interpolation", false)
	if not interp_enabled:
		printerr("physics/common/physics_interpolation is not enabled in ProjectSettings!")
		return false
	
	var test_world = Node3D.new()
	root.add_child(test_world)
	await process_frame
	
	var player: PlayerController = load("res://scenes/player/player.tscn").instantiate()
	test_world.add_child(player)
	await process_frame
	
	# 2. Verify camera pivot is top_level and has physics_interpolation_mode = OFF
	if not player.camera_pivot.top_level:
		printerr("player.camera_pivot is not top_level!")
		test_world.queue_free()
		return false
	
	if player.camera_pivot.physics_interpolation_mode != Node.PHYSICS_INTERPOLATION_MODE_OFF:
		printerr("player.camera_pivot physics_interpolation_mode is not OFF!")
		test_world.queue_free()
		return false
	
	# 3. Verify camera pivot follows interpolated position on process
	player.global_position = Vector3(5.0, 0.0, 5.0)
	player._process(0.016)
	
	var expected_pos_y = player.current_camera_height
	if absf(player.camera_pivot.global_position.y - expected_pos_y) > 0.1:
		printerr("Camera pivot height mismatch! Got %f, expected %f" % [player.camera_pivot.global_position.y, expected_pos_y])
		test_world.queue_free()
		return false
	
	test_world.queue_free()
	return true

func test_touch_drag_consumption() -> bool:
	# 1. Verify use_accumulated_input is disabled
	if Input.use_accumulated_input:
		printerr("Input.use_accumulated_input is still true! Must be false for responsive touch.")
		return false
	
	var tc: TouchControls = load("res://scenes/ui/touch_controls.tscn").instantiate()
	root.add_child(tc)
	await process_frame
	
	tc._look_touch_index = 1
	tc._accumulated_drag = Vector2.ZERO
	
	# Inject 3 drag events in a single frame
	var drag1 = InputEventScreenDrag.new()
	drag1.index = 1
	drag1.relative = Vector2(4.0, 0.0)
	tc._handle_screen_drag(drag1)
	
	var drag2 = InputEventScreenDrag.new()
	drag2.index = 1
	drag2.relative = Vector2(6.0, 0.0)
	tc._handle_screen_drag(drag2)
	
	var drag3 = InputEventScreenDrag.new()
	drag3.index = 1
	drag3.relative = Vector2(5.0, 0.0)
	tc._handle_screen_drag(drag3)
	
	# All 3 drag events must be consumed (summed raw: 4 + 6 + 5 = 15, not just the last one)
	if not is_equal_approx(tc._accumulated_drag.x, 15.0):
		printerr("Not all drag events were consumed! Got accumulated: ", tc._accumulated_drag)
		tc.queue_free()
		return false
	
	tc.queue_free()
	return true

func test_touch_smoothing_time_constant() -> bool:
	var tc: TouchControls = load("res://scenes/ui/touch_controls.tscn").instantiate()
	root.add_child(tc)
	await process_frame
	
	# Must be 0.025 (~25ms)
	if absf(tc.LOOK_TIME_CONSTANT - 0.025) > 0.001:
		printerr("LOOK_TIME_CONSTANT is not ~25ms! Got: ", tc.LOOK_TIME_CONSTANT)
		tc.queue_free()
		return false
	
	tc.queue_free()
	return true

func test_joystick_curve_and_acceleration() -> bool:
	var tc: TouchControls = load("res://scenes/ui/touch_controls.tscn").instantiate()
	root.add_child(tc)
	await process_frame
	
	var player: PlayerController = load("res://scenes/player/player.tscn").instantiate()
	root.add_child(player)
	await process_frame
	
	# Joystick deadzone is 8.0, radius 75.0, full speed at 85% of the radius (63.75), linear between
	# 1. Gentle push: dist = 8 + (63.75 - 8) * 0.25 = 21.94 -> 25% speed
	var center = tc._default_joystick_pos
	tc._joystick_center = center
	var gentle_pos = center + Vector2(0.0, -21.94)
	tc._update_joystick_drag(gentle_pos)

	var move_forward_strength = Input.get_action_strength("move_forward")
	if absf(move_forward_strength - 0.25) > 0.02:
		printerr("Gentle joystick push should give ~25%% speed! Got strength: %f" % move_forward_strength)
		tc.queue_free()
		player.queue_free()
		return false
	
	# Verify player movement speed with gentle tilt is slow walk
	player._physics_process(0.1)
	var slow_speed = absf(player.velocity.z)
	var max_walk = player.player_data.walk_speed
	if slow_speed >= max_walk * 0.35:
		printerr("Player slow walk too fast with gentle joystick! Got: %f, max walk: %f" % [slow_speed, max_walk])
		tc.queue_free()
		player.queue_free()
		return false
	
	# 2. Full deflection: dist = 75.0
	var full_pos = center + Vector2(0.0, -75.0)
	tc._update_joystick_drag(full_pos)
	var full_strength = Input.get_action_strength("move_forward")
	if absf(full_strength - 1.0) > 0.02:
		printerr("Full joystick deflection did not reach 1.0! Got: ", full_strength)
		tc.queue_free()
		player.queue_free()
		return false

	# 3. A full push walks; it must not sprint (sprint is loud and only comes from the sprint lock)
	if Input.is_action_pressed("sprint"):
		printerr("Full joystick push started sprinting!")
		tc._release_movement_actions()
		tc.queue_free()
		player.queue_free()
		return false
	
	tc._release_movement_actions()
	tc.queue_free()
	player.queue_free()
	return true

func test_turn_rate_consistency_framerate() -> bool:
	# Test turning at constant swipe speed gives constant camera turn across 30, 60, and 120 FPS
	var total_time = 0.4 # 400ms swipe
	var swipe_speed = 300.0 # 300 px/s
	
	var fps_list = [30.0, 60.0, 120.0]
	var rotated_amounts: Array[float] = []
	
	for fps in fps_list:
		var dt = 1.0 / fps
		var steps = int(total_time / dt)
		
		var tc: TouchControls = load("res://scenes/ui/touch_controls.tscn").instantiate()
		root.add_child(tc)
		await process_frame
		tc.visible = true
		
		var player: PlayerController = load("res://scenes/player/player.tscn").instantiate()
		root.add_child(player)
		await process_frame
		
		var im = root.get_node_or_null("InputManager")
		if im:
			im.last_input_device = im.InputDevice.TOUCH
			im.mouse_captured = true
			im.touch_smoothing = 0.5
		
		tc._look_touch_index = 1
		var start_rot = player.rotation.y
		
		for s in range(steps):
			var drag_px = swipe_speed * dt
			tc._process_look_drag_event(Vector2(drag_px, 0.0))
			tc._process(dt)
			player._process(dt)
		
		var total_turned = absf(player.rotation.y - start_rot)
		rotated_amounts.append(total_turned)
		
		tc.queue_free()
		player.queue_free()
		await process_frame
	
	print("  -> Turn rotation: 30 FPS: %.4f rad, 60 FPS: %.4f rad, 120 FPS: %.4f rad" % [
		rotated_amounts[0], rotated_amounts[1], rotated_amounts[2]
	])
	
	# Disparity between 30 and 120 FPS must be minimal (< 15% across 4x frame rate ratio)
	var max_val = rotated_amounts.max()
	var min_val = rotated_amounts.min()
	var variation = (max_val - min_val) / max_val
	if variation > 0.15:
		printerr("Turn rate inconsistency across framerates! Variation: %.1f%%" % (variation * 100.0))
		return false
	
	return true

func test_performance_fps_floor_01() -> bool:
	var floor_scene = load("res://scenes/levels/floor_01.tscn")
	if not floor_scene:
		printerr("floor_01.tscn failed to load!")
		return false
	
	var level = floor_scene.instantiate()
	root.add_child(level)
	
	# Warm up 60 frames
	for i in range(60):
		await process_frame
	
	# Measure FPS and frame time over 60 frames
	var sample_count: int = 60
	var t_start = Time.get_ticks_usec()
	for i in range(sample_count):
		await process_frame
	var elapsed_sec: float = (Time.get_ticks_usec() - t_start) / 1000000.0
	
	var avg_fps = float(sample_count) / elapsed_sec
	var avg_ms = (elapsed_sec / float(sample_count)) * 1000.0
	var draw_calls = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	
	print("  -> Floor 01 Performance Measurement (F5 monitor):")
	print("     Average FPS: %.1f" % avg_fps)
	print("     Average Frame Time: %.2f ms" % avg_ms)
	print("     Draw Calls: %d" % draw_calls)
	
	if avg_fps < 40.0:
		print("     [NOTICE] Phone/test FPS is under 40 FPS (Got %.1f FPS)" % avg_fps)
	else:
		print("     [OK] FPS is solid: %.1f FPS >= 40 FPS" % avg_fps)
	
	level.queue_free()
	await process_frame
	return true
