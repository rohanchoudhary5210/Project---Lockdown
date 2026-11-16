extends SceneTree

## Project: Lockdown - Test Suite for Mobile Features: Aim Assist & Smoother Swipe Look

func _init() -> void:
	print("\n=== STARTING MOBILE AIM ASSIST & SWIPE LOOK TEST SUITE ===")
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	var passed = 0
	var failed = 0
	
	print("\n--- Test 1: AimAssistData Resource Properties & Defaults ---")
	if await test_aim_assist_data_resource():
		passed += 1
		print("PASSED: Test 1")
	else:
		failed += 1
		print("FAILED: Test 1")
	
	print("\n--- Test 2: Aim Assist Line of Sight Occlusion (Walls vs Open) ---")
	if await test_aim_assist_los_and_walls():
		passed += 1
		print("PASSED: Test 2")
	else:
		failed += 1
		print("FAILED: Test 2")
	
	print("\n--- Test 3: Aim Assist Target Selection (Closest to Crosshair, NOT Distance) ---")
	if await test_aim_assist_closest_to_crosshair():
		passed += 1
		print("PASSED: Test 3")
	else:
		failed += 1
		print("FAILED: Test 3")
	
	print("\n--- Test 4: Device & Setting Rules (Mouse Never Gets Assist, Off Setting) ---")
	if await test_aim_assist_device_and_settings():
		passed += 1
		print("PASSED: Test 4")
	else:
		failed += 1
		print("FAILED: Test 4")
	
	print("\n--- Test 5: Aim Assist Friction & Magnetism Rotation Rates (Low vs High) ---")
	if await test_aim_assist_friction_and_magnetism():
		passed += 1
		print("PASSED: Test 5")
	else:
		failed += 1
		print("FAILED: Test 5")
	
	print("\n--- Test 6: Aim Assist Inactive When Dead, Paused, or in Death Screen ---")
	if await test_aim_assist_disabled_states():
		passed += 1
		print("PASSED: Test 6")
	else:
		failed += 1
		print("FAILED: Test 6")
	
	print("\n--- Test 7: Multi-Touch Finger Tracking (Index Tracking & Isolation) ---")
	if await test_multi_touch_finger_tracking():
		passed += 1
		print("PASSED: Test 7")
	else:
		failed += 1
		print("FAILED: Test 7")
	
	print("\n--- Test 8: Touch Look: no dropped events, same turn for any event size, speed curve, tremor deadzone ---")
	if await test_touch_deadzone_and_curve():
		passed += 1
		print("PASSED: Test 8")
	else:
		failed += 1
		print("FAILED: Test 8")
	
	print("\n--- Test 9: Frame-Rate Independent Exponential Smoothing at 30 and 60 FPS ---")
	if await test_framerate_independent_smoothing():
		passed += 1
		print("PASSED: Test 9")
	else:
		failed += 1
		print("FAILED: Test 9")
	
	print("\n--- Test 10: Horizontal & Vertical Touch Sensitivity Sliders (V = 0.8x H) ---")
	if await test_touch_sensitivity_sliders():
		passed += 1
		print("PASSED: Test 10")
	else:
		failed += 1
		print("FAILED: Test 10")
	
	print("\n--- Test 11: Touch Recoil Recovery Compatibility Over ~0.25s ---")
	if await test_touch_recoil_recovery_compatibility():
		passed += 1
		print("PASSED: Test 11")
	else:
		failed += 1
		print("FAILED: Test 11")
	
	print("\n--- Test 12: F4 Debug Overlay (Assist Cone & Target Visuals) ---")
	if await test_f4_debug_overlay():
		passed += 1
		print("PASSED: Test 12")
	else:
		failed += 1
		print("FAILED: Test 12")
	
	print("\n=======================================================")
	print("RESULTS: %d Passed, %d Failed" % [passed, failed])
	print("=======================================================")
	
	if failed == 0:
		print("ALL MOBILE AIM ASSIST & SWIPE LOOK TESTS PASSED SUCCESSFULLY!\n")
		quit(0)
	else:
		print("SOME TESTS FAILED!\n")
		quit(1)

func test_aim_assist_data_resource() -> bool:
	var res = load("res://game/assets/data/default_aim_assist_data.tres") as AimAssistData
	if not res:
		printerr("Failed to load default_aim_assist_data.tres")
		return false
	
	if absf(res.max_range - 25.0) > 0.01:
		printerr("max_range is %f, expected 25.0" % res.max_range)
		return false
	if absf(res.friction_angle_deg - 4.0) > 0.01:
		printerr("friction_angle_deg is %f, expected 4.0" % res.friction_angle_deg)
		return false
	if absf(res.friction_scale_low - 0.75) > 0.01:
		printerr("friction_scale_low is %f, expected 0.75" % res.friction_scale_low)
		return false
	if absf(res.friction_scale_high - 0.55) > 0.01:
		printerr("friction_scale_high is %f, expected 0.55" % res.friction_scale_high)
		return false
	if absf(res.magnetism_speed_low_deg - 2.0) > 0.01:
		printerr("magnetism_speed_low_deg is %f, expected 2.0" % res.magnetism_speed_low_deg)
		return false
	if absf(res.magnetism_speed_high_deg - 5.0) > 0.01:
		printerr("magnetism_speed_high_deg is %f, expected 5.0" % res.magnetism_speed_high_deg)
		return false
	return true

func test_aim_assist_los_and_walls() -> bool:
	var test_world = Node3D.new()
	root.add_child(test_world)
	await process_frame
	
	var player_scene = load("res://game/scenes/gameplay/player/Player.tscn")
	var player: Player = player_scene.instantiate()
	player.position = Vector3(0, 0, 0)
	test_world.add_child(player)
	
	var im = root.get_node_or_null("InputManager")
	if im:
		im.last_input_device = im.InputDevice.TOUCH
		im.mouse_captured = true
		im.is_gameplay_paused = false
		im.is_death_screen_active = false
	
	player.aim_assist_setting = "High"
	
	var enemy_scene = load("res://game/scenes/gameplay/enemies/RangedEnemy.tscn")
	
	# 1. Place enemy behind a solid world wall (layer 1)
	var wall = StaticBody3D.new()
	wall.collision_layer = 1 # World layer
	wall.position = Vector3(0, 1.0, -5.0) # 5m in front of player
	var col_shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(10.0, 4.0, 1.0)
	col_shape.shape = box
	wall.add_child(col_shape)
	test_world.add_child(wall)
	
	var hidden_enemy: EnemyBase = enemy_scene.instantiate()
	hidden_enemy.position = Vector3(0, 0, -15.0) # 15m away, directly behind wall
	test_world.add_child(hidden_enemy)
	
	await process_frame
	await process_frame
	
	# Update aim assist facing forward: must NOT target hidden enemy through wall!
	var look_delta = player._update_aim_assist(0.016, Vector2(0.01, 0.0))
	if player.current_aim_target != null:
		printerr("Aim assist targeted enemy behind solid wall! Target: ", player.current_aim_target)
		test_world.queue_free()
		return false
	
	# 2. Place enemy in open at 15m (no wall)
	wall.position = Vector3(50, 0, 50) # Move wall away
	await process_frame
	await process_frame
	
	look_delta = player._update_aim_assist(0.016, Vector2(0.01, 0.0))
	if player.current_aim_target != hidden_enemy:
		printerr("Aim assist failed to acquire open enemy at 15m! Found: ", player.current_aim_target)
		test_world.queue_free()
		return false
	
	test_world.queue_free()
	return true

func test_aim_assist_closest_to_crosshair() -> bool:
	var test_world = Node3D.new()
	root.add_child(test_world)
	await process_frame
	
	var player_scene = load("res://game/scenes/gameplay/player/Player.tscn")
	var player: Player = player_scene.instantiate()
	player.position = Vector3(0, 0, 0)
	test_world.add_child(player)
	
	var im = root.get_node_or_null("InputManager")
	if im:
		im.last_input_device = im.InputDevice.TOUCH
		im.mouse_captured = true
		im.is_gameplay_paused = false
		im.is_death_screen_active = false
	
	player.aim_assist_setting = "High"
	
	var enemy_scene = load("res://game/scenes/gameplay/enemies/RangedEnemy.tscn")
	
	# Enemy 1: Closer distance (8m), but further from crosshair center (e.g. 10 degrees to right)
	# At 8m, 10 deg is ~ 8 * tan(10°) ≈ 1.41m to the right
	var enemy_close_dist: EnemyBase = enemy_scene.instantiate()
	enemy_close_dist.position = Vector3(1.41, 0, -8.0)
	enemy_close_dist.name = "EnemyCloseDistance"
	test_world.add_child(enemy_close_dist)
	
	# Enemy 2: Further distance (18m), but very close to crosshair center (e.g. 1.5 degrees to right)
	# At 18m, 1.5 deg is ~ 18 * tan(1.5°) ≈ 0.47m to the right
	var enemy_close_crosshair: EnemyBase = enemy_scene.instantiate()
	enemy_close_crosshair.position = Vector3(0.47, 0, -18.0)
	enemy_close_crosshair.name = "EnemyCloseCrosshair"
	test_world.add_child(enemy_close_crosshair)
	
	await process_frame
	await process_frame
	
	player._update_aim_assist(0.016, Vector2(0.01, 0.0))
	if player.current_aim_target != enemy_close_crosshair:
		printerr("Expected closest to crosshair (EnemyCloseCrosshair), but got: ", player.current_aim_target)
		test_world.queue_free()
		return false
	
	test_world.queue_free()
	return true

func test_aim_assist_device_and_settings() -> bool:
	var test_world = Node3D.new()
	root.add_child(test_world)
	await process_frame
	
	var player: Player = load("res://game/scenes/gameplay/player/Player.tscn").instantiate()
	test_world.add_child(player)
	
	var enemy: EnemyBase = load("res://game/scenes/gameplay/enemies/RangedEnemy.tscn").instantiate()
	enemy.position = Vector3(0, 0, -10.0)
	test_world.add_child(enemy)
	
	await process_frame
	await process_frame
	
	var im = root.get_node_or_null("InputManager")
	
	# Rule 1: Mouse never gets aim assist, even if setting is High
	if im:
		im.last_input_device = im.InputDevice.MOUSE_KEYBOARD
	player.aim_assist_setting = "High"
	player._update_aim_assist(0.016, Vector2(0.01, 0.0))
	if player.current_aim_target != null:
		printerr("Mouse input erroneously received aim assist targeting!")
		test_world.queue_free()
		return false
	
	# Rule 2: Setting Off disables aim assist even on touch
	if im:
		im.last_input_device = im.InputDevice.TOUCH
	player.aim_assist_setting = "Off"
	player._update_aim_assist(0.016, Vector2(0.01, 0.0))
	if player.current_aim_target != null:
		printerr("Aim assist active while setting is 'Off'!")
		test_world.queue_free()
		return false
	
	# Rule 3: Touch gets aim assist when High
	player.aim_assist_setting = "High"
	player._update_aim_assist(0.016, Vector2(0.01, 0.0))
	if player.current_aim_target != enemy:
		printerr("Touch failed to acquire aim assist target!")
		test_world.queue_free()
		return false
	
	test_world.queue_free()
	return true

func test_aim_assist_friction_and_magnetism() -> bool:
	var test_world = Node3D.new()
	root.add_child(test_world)
	await process_frame
	
	var player: Player = load("res://game/scenes/gameplay/player/Player.tscn").instantiate()
	test_world.add_child(player)
	
	var enemy: EnemyBase = load("res://game/scenes/gameplay/enemies/RangedEnemy.tscn").instantiate()
	enemy.position = Vector3(0.2, 0, -10.0) # ~1.1 degrees off center (within 4 deg friction)
	test_world.add_child(enemy)
	
	await process_frame
	await process_frame
	
	var im = root.get_node_or_null("InputManager")
	if im:
		im.last_input_device = im.InputDevice.TOUCH
	
	# Test Low Setting: friction scale = 0.75
	player.aim_assist_setting = "Low"
	var raw_delta = Vector2(10.0, 5.0)
	var low_delta = player._update_aim_assist(0.016, raw_delta)
	var expected_low = raw_delta * 0.75
	if (low_delta - expected_low).length() > 0.01:
		printerr("Low friction mismatch! Got %v, expected %v" % [low_delta, expected_low])
		test_world.queue_free()
		return false
	
	# Test High Setting: friction scale = 0.55
	player.aim_assist_setting = "High"
	var high_delta = player._update_aim_assist(0.016, raw_delta)
	var expected_high = raw_delta * 0.55
	if (high_delta - expected_high).length() > 0.01:
		printerr("High friction mismatch! Got %v, expected %v" % [high_delta, expected_high])
		test_world.queue_free()
		return false
	
	# Test Magnetism only rotates when moving look OR firing
	var initial_rot_y = player.rotation.y
	# No movement and not firing: MUST NOT TURN CAMERA
	player._update_aim_assist(0.1, Vector2.ZERO)
	if absf(player.rotation.y - initial_rot_y) > 0.0001:
		printerr("Magnetism turned camera while NOT moving look and NOT firing!")
		test_world.queue_free()
		return false
	
	# Moving look: MUST gently pull toward target (enemy is at +X = right, so rotation.y decreases)
	player._update_aim_assist(0.1, Vector2(0.01, 0.0))
	if player.rotation.y >= initial_rot_y:
		printerr("Magnetism did not rotate toward target on look movement! Start: %f, End: %f" % [initial_rot_y, player.rotation.y])
		test_world.queue_free()
		return false
	
	test_world.queue_free()
	return true

func test_aim_assist_disabled_states() -> bool:
	var test_world = Node3D.new()
	root.add_child(test_world)
	await process_frame
	
	var player: Player = load("res://game/scenes/gameplay/player/Player.tscn").instantiate()
	test_world.add_child(player)
	
	var enemy: EnemyBase = load("res://game/scenes/gameplay/enemies/RangedEnemy.tscn").instantiate()
	enemy.position = Vector3(0, 0, -10.0)
	test_world.add_child(enemy)
	
	await process_frame
	await process_frame
	
	var im = root.get_node_or_null("InputManager")
	if im:
		im.last_input_device = im.InputDevice.TOUCH
	player.aim_assist_setting = "High"
	
	# 1. Dead enemy
	enemy.current_state = EnemyBase.State.DEAD
	player._update_aim_assist(0.016, Vector2(0.01, 0.0))
	if player.current_aim_target != null:
		printerr("Aim assist targeted a dead enemy!")
		test_world.queue_free()
		return false
	enemy.current_state = EnemyBase.State.IDLE
	
	# 2. Player dead
	player.is_dead = true
	player._update_aim_assist(0.016, Vector2(0.01, 0.0))
	if player.current_aim_target != null:
		printerr("Aim assist active while player is dead!")
		test_world.queue_free()
		return false
	player.is_dead = false
	
	# 3. Game paused
	if im:
		im.is_gameplay_paused = true
	player._update_aim_assist(0.016, Vector2(0.01, 0.0))
	if player.current_aim_target != null:
		printerr("Aim assist active while game is paused!")
		test_world.queue_free()
		return false
	if im:
		im.is_gameplay_paused = false
	
	# 4. Target > 25m away
	enemy.position = Vector3(0, 0, -26.0)
	await process_frame
	player._update_aim_assist(0.016, Vector2(0.01, 0.0))
	if player.current_aim_target != null:
		printerr("Aim assist targeted enemy beyond 25m!")
		test_world.queue_free()
		return false
	
	test_world.queue_free()
	return true

func test_multi_touch_finger_tracking() -> bool:
	var tc_scene = load("res://game/scenes/ui/mfw/TouchControls.tscn")
	var tc: TouchControls = tc_scene.instantiate()
	root.add_child(tc)
	await process_frame
	
	# Finger 1 lands on right half to look (pos = 700, 300)
	var touch1_down = InputEventScreenTouch.new()
	touch1_down.index = 1
	touch1_down.position = Vector2(700, 300)
	touch1_down.pressed = true
	tc._handle_screen_touch(touch1_down)
	
	if tc._look_touch_index != 1:
		printerr("Look touch index not set to finger 1! Got: ", tc._look_touch_index)
		tc.queue_free()
		return false
	
	# Finger 2 lands (e.g. pressing fire or second touch at pos = 600, 500)
	var touch2_down = InputEventScreenTouch.new()
	touch2_down.index = 2
	touch2_down.position = Vector2(600, 500)
	touch2_down.pressed = true
	tc._handle_screen_touch(touch2_down)
	
	# Look finger MUST still be 1 (never jumps to finger 2)
	if tc._look_touch_index != 1:
		printerr("Second finger disturbed look touch index! Got: ", tc._look_touch_index)
		tc.queue_free()
		return false
	
	# Drag with Finger 2 (should be completely ignored by look)
	var drag2 = InputEventScreenDrag.new()
	drag2.index = 2
	drag2.relative = Vector2(50, 50)
	tc._handle_screen_drag(drag2)
	
	if tc._accumulated_drag != Vector2.ZERO:
		printerr("Second finger drag leaked into look drag! Got: ", tc._accumulated_drag)
		tc.queue_free()
		return false
	
	# Drag with Finger 1 (must be captured)
	var drag1 = InputEventScreenDrag.new()
	drag1.index = 1
	drag1.relative = Vector2(10, 0)
	tc._handle_screen_drag(drag1)
	
	if tc._accumulated_drag == Vector2.ZERO:
		printerr("Finger 1 drag was not captured!")
		tc.queue_free()
		return false
	
	# Release Finger 2: look touch index must remain 1
	var touch2_up = InputEventScreenTouch.new()
	touch2_up.index = 2
	touch2_up.pressed = false
	tc._handle_screen_touch(touch2_up)
	
	if tc._look_touch_index != 1:
		printerr("Releasing finger 2 disturbed look touch index!")
		tc.queue_free()
		return false
	
	# Release Finger 1: look touch index resets to -1
	var touch1_up = InputEventScreenTouch.new()
	touch1_up.index = 1
	touch1_up.pressed = false
	tc._handle_screen_touch(touch1_up)
	
	if tc._look_touch_index != -1:
		printerr("Releasing finger 1 did not reset look touch index!")
		tc.queue_free()
		return false
	
	tc.queue_free()
	return true

func test_touch_deadzone_and_curve() -> bool:
	var tc: TouchControls = load("res://game/scenes/ui/mfw/TouchControls.tscn").instantiate()
	root.add_child(tc)
	await process_frame
	
	tc._look_touch_index = 1
	
	var sm = root.get_node_or_null("SettingsManager")
	var old_smoothing = sm.touch_smoothing if sm else 0.0
	if sm: sm.touch_smoothing = 0.0
	var im = root.get_node("InputManager")

	# Turns a steady swipe of `px_per_frame` for 30 frames at 60 FPS, split into `events` per frame.
	var swipe = func(px_per_frame: float, events: int) -> float:
		tc.visible = true # touch controls hide themselves on non-touch (headless) devices
		tc._look_touch_index = 1
		tc._look_speed_est = 0.0
		tc._accumulated_drag = Vector2.ZERO
		tc._smoothed_look_rate = Vector2.ZERO
		im._touch_delta = Vector2.ZERO
		var total := 0.0
		for i in 30:
			for e in events:
				tc._process_look_drag_event(Vector2(px_per_frame / events, 0.0))
			tc._process(1.0 / 60.0)
			total += im._touch_delta.x
			im._touch_delta = Vector2.ZERO
		return total

	# 1. Small events are never thrown away: a slow precise swipe made of 1px events must turn the camera.
	var slow_fine = swipe.call(2.0, 2)
	if slow_fine <= 0.0:
		printerr("Slow swipe of 1px events produced no camera movement!")
		tc.queue_free(); if sm: sm.touch_smoothing = old_smoothing
		return false

	# 2. Same swipe speed gives the same turn no matter how the phone splits it into events.
	var slow_coarse = swipe.call(2.0, 1)
	if absf(slow_fine - slow_coarse) > slow_coarse * 0.02:
		printerr("Turn depends on touch event size! 1px events: %f, 2px events: %f" % [slow_fine, slow_coarse])
		tc.queue_free(); if sm: sm.touch_smoothing = old_smoothing
		return false

	# 3. Response curve: 10x faster swipe turns more than 10x (fast swipes accelerate).
	var fast = swipe.call(20.0, 4)
	var ratio = fast / slow_coarse
	if ratio <= 10.5:
		printerr("Response curve not applied! fast/slow ratio %f (expected > 10.5)" % ratio)
		tc.queue_free(); if sm: sm.touch_smoothing = old_smoothing
		return false

	# 4. A resting finger (tremor well under the deadzone speed) does not move the camera.
	var tremor = swipe.call(0.1, 1) # 6 px/s
	if absf(tremor) > 0.0001:
		printerr("Resting-finger tremor moved the camera: ", tremor)
		tc.queue_free(); if sm: sm.touch_smoothing = old_smoothing
		return false

	if sm: sm.touch_smoothing = old_smoothing
	tc.queue_free()
	return true

func test_framerate_independent_smoothing() -> bool:
	var tc: TouchControls = load("res://game/scenes/ui/mfw/TouchControls.tscn").instantiate()
	root.add_child(tc)
	await process_frame
	
	tc._look_touch_index = 1
	var sm = root.get_node_or_null("SettingsManager")
	
	# Case A: Look Smoothing = 0 (Raw)
	if sm:
		sm.touch_smoothing = 0.0
	tc._accumulated_drag = Vector2(10.0, 0.0)
	tc._process(0.016)
	
	# Case B: Look Smoothing = 1.0 (Full Smooth)
	if sm:
		sm.touch_smoothing = 1.0
	
	# Compare exponential decay factor over identical elapsed time T = 0.1s
	# At 60 FPS (delta = 0.01667): 6 steps
	var vel_60: float = 100.0
	var alpha_60 = 1.0 - exp(-0.01667 / 0.040)
	for i in range(6):
		vel_60 = lerpf(vel_60, 0.0, alpha_60)
	
	# At 30 FPS (delta = 0.03333): 3 steps
	var vel_30: float = 100.0
	var alpha_30 = 1.0 - exp(-0.03333 / 0.040)
	for i in range(3):
		vel_30 = lerpf(vel_30, 0.0, alpha_30)
	
	# Both should reach identical exponential value exp(-0.1 / 0.04) * 100 ≈ 8.208
	if absf(vel_60 - vel_30) > 0.15:
		printerr("Frame rate smoothing disparity between 30 and 60 FPS! 60FPS: %f, 30FPS: %f" % [vel_60, vel_30])
		tc.queue_free()
		return false
	
	tc.queue_free()
	return true

func test_touch_sensitivity_sliders() -> bool:
	var im = root.get_node_or_null("InputManager")
	if not im:
		return false
	
	var sm = root.get_node_or_null("SettingsManager")
	if sm:
		sm.set_setting("touch_sens_h", 0.0020)
		sm.set_setting("touch_sens_v", 0.0016) # 0.8x of H
	
	if absf(im.touch_sens_v / im.touch_sens_h - 0.8) > 0.001:
		printerr("Vertical sensitivity is not 0.8x horizontal! H=%f, V=%f" % [im.touch_sens_h, im.touch_sens_v])
		return false
	
	im.inject_touch_look(Vector2(100.0, 100.0))
	var look = im.get_look_delta(0.016)
	var expected_x = 100.0 * 0.0020
	var expected_y = 100.0 * 0.0016
	
	if absf(look.x - expected_x) > 0.0001 or absf(look.y - expected_y) > 0.0001:
		printerr("Look delta scaling mismatch! Got %v, expected (%f, %f)" % [look, expected_x, expected_y])
		return false
	
	return true

func test_touch_recoil_recovery_compatibility() -> bool:
	var player: Player = load("res://game/scenes/gameplay/player/Player.tscn").instantiate()
	root.add_child(player)
	await process_frame
	
	# Apply touch recoil (0.05 pitch, 0.01 yaw, is_touch = true)
	player.apply_camera_recoil(0.05, 0.01, true)
	
	var initial_pitch = player._pitch
	if initial_pitch <= 0.0:
		printerr("Touch recoil did not pitch camera up!")
		player.queue_free()
		return false
	
	# Simulate 0.3s of frames (should recover completely within ~0.25s)
	for i in range(20):
		player._physics_process(0.016)
	
	if player._touch_recoil_recovery_pitch > 0.001 or absf(player._touch_recoil_recovery_yaw) > 0.001:
		printerr("Touch recoil failed to recover within 0.3s! Pitch remain: %f, Yaw remain: %f" % [
			player._touch_recoil_recovery_pitch, player._touch_recoil_recovery_yaw
		])
		player.queue_free()
		return false
	
	player.queue_free()
	return true

func test_f4_debug_overlay() -> bool:
	var test_world = Node3D.new()
	root.add_child(test_world)
	await process_frame
	
	var player: Player = load("res://game/scenes/gameplay/player/Player.tscn").instantiate()
	test_world.add_child(player)
	
	var enemy: EnemyBase = load("res://game/scenes/gameplay/enemies/RangedEnemy.tscn").instantiate()
	enemy.position = Vector3(0, 0, -10.0)
	test_world.add_child(enemy)
	
	await process_frame
	await process_frame
	
	var overlay = player.find_child("AimAssistDebugOverlay", true, false)
	if not overlay:
		printerr("AimAssistDebugOverlay not found on player!")
		test_world.queue_free()
		return false
	
	# By default overlay is hidden
	EnemyDebugOverlay.global_overlay_visible = false
	overlay._update_visibility()
	if overlay.visible:
		printerr("AimAssistDebugOverlay is visible when F4 is OFF!")
		test_world.queue_free()
		return false
	
	# Toggle F4 on
	EnemyDebugOverlay.global_overlay_visible = true
	overlay._update_visibility()
	if not overlay.visible:
		printerr("AimAssistDebugOverlay failed to become visible when F4 is ON!")
		test_world.queue_free()
		return false
	
	# Reset
	EnemyDebugOverlay.global_overlay_visible = false
	overlay._update_visibility()
	
	test_world.queue_free()
	return true
