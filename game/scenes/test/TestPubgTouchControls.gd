extends SceneTree

## Project: Lockdown - Test Suite for PUBG Mobile Style Touch Controls & Customization

func _init() -> void:
	print("\n=== STARTING PUBG MOBILE TOUCH CONTROLS TEST SUITE ===")
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	var passed = 0
	var failed = 0
	
	print("\n--- Test 1: Layout Validation at 1920x1080 (No Overlaps, Safe Area, All >= 64px) ---")
	if await test_layout_at_resolution(Vector2i(1920, 1080)):
		passed += 1
		print("PASSED: Test 1")
	else:
		failed += 1
		print("FAILED: Test 1")
	
	print("\n--- Test 2: Layout Validation at 2400x1080 (No Overlaps, Safe Area, All >= 64px) ---")
	if await test_layout_at_resolution(Vector2i(2400, 1080)):
		passed += 1
		print("PASSED: Test 2")
	else:
		failed += 1
		print("FAILED: Test 2")
	
	print("\n--- Test 3: Joystick Zone & Following Thumb Drift ---")
	if await test_joystick_zone_and_following():
		passed += 1
		print("PASSED: Test 3")
	else:
		failed += 1
		print("FAILED: Test 3")
	
	print("\n--- Test 4: Sprint Lock (Drag Up to Lock, Auto-Sprint, Pull Down / Tap to Cancel) ---")
	if await test_sprint_lock():
		passed += 1
		print("PASSED: Test 4")
	else:
		failed += 1
		print("FAILED: Test 4")
	
	print("\n--- Test 5: Left Fire Button & Main Fire Button Actions ---")
	if await test_fire_buttons():
		passed += 1
		print("PASSED: Test 5")
	else:
		failed += 1
		print("FAILED: Test 5")
	
	print("\n--- Test 6: Fire-and-Drag Aiming (Aiming While Shooting) ---")
	if await test_fire_and_drag_aiming():
		passed += 1
		print("PASSED: Test 6")
	else:
		failed += 1
		print("FAILED: Test 6")
	
	print("\n--- Test 7: Combat & Stance Actions (Jump, Crouch Toggle, Reload, Melee, Block Hold) ---")
	if await test_combat_buttons():
		passed += 1
		print("PASSED: Test 7")
	else:
		failed += 1
		print("FAILED: Test 7")
	
	print("\n--- Test 8: Contextual Interact Button (Dynamic Prompt & Hold-to-Rescue) ---")
	if await test_interact_button():
		passed += 1
		print("PASSED: Test 8")
	else:
		failed += 1
		print("FAILED: Test 8")
	
	print("\n--- Test 9: HUD Customization (Drag Reposition, 0.6x-1.5x Resize, Min 64px) ---")
	if await test_hud_customization_edit():
		passed += 1
		print("PASSED: Test 9")
	else:
		failed += 1
		print("FAILED: Test 9")
	
	print("\n--- Test 10: HUD Customization Persistence (Per Aspect Ratio & Reset Default) ---")
	if await test_hud_customization_persistence():
		passed += 1
		print("PASSED: Test 10")
	else:
		failed += 1
		print("FAILED: Test 10")
	
	print("\n--- Test 11: Gyroscope Aim (Off / Always / While Firing & Sensitivity) ---")
	if await test_gyroscope_aim():
		passed += 1
		print("PASSED: Test 11")
	else:
		failed += 1
		print("FAILED: Test 11")
	
	print("\n=======================================================")
	print("RESULTS: %d Passed, %d Failed" % [passed, failed])
	print("=======================================================")
	
	if failed == 0:
		print("ALL PUBG TOUCH CONTROLS & CUSTOMIZATION TESTS PASSED!\n")
		quit(0)
	else:
		print("SOME TESTS FAILED!\n")
		quit(1)

func test_layout_at_resolution(res: Vector2i) -> bool:
	root.size = res
	await process_frame
	
	var tc_scene = load("res://game/scenes/ui/mfw/TouchControls.tscn")
	var tc: TouchControls = tc_scene.instantiate()
	root.add_child(tc)
	await process_frame
	
	tc.apply_default_layout()
	await process_frame
	
	var buttons = tc._get_all_buttons()
	var vp_size = tc.get_viewport_rect().size
	
	var safe_left = 24.0
	var safe_top = 24.0
	var safe_right = 24.0
	var safe_bottom = 24.0
	
	# 1. Verify every button is >= 64px
	for b in buttons:
		if b.size.x < 63.9 or b.size.y < 63.9:
			printerr("Button %s size %v is under minimum 64px!" % [b.name, b.size])
			tc.queue_free()
			return false
	
	# 2. Verify all buttons are within safe area bounds
	for b in buttons:
		var rect = b.get_global_rect()
		print("    Button %s: rect=%s" % [b.name, rect])
		if rect.position.x < safe_left - 1.0:
			printerr("Button %s extends past left safe margin! Rect: %s, safe_left: %f" % [b.name, rect, safe_left])
			tc.queue_free()
			return false
		if rect.position.y < safe_top - 1.0:
			printerr("Button %s extends past top safe margin! Rect: %s, safe_top: %f" % [b.name, rect, safe_top])
			tc.queue_free()
			return false
		if rect.end.x > vp_size.x - safe_right + 1.0:
			printerr("Button %s extends past right safe margin! Rect: %s, max_x: %f" % [b.name, rect, vp_size.x - safe_right])
			tc.queue_free()
			return false
		if rect.end.y > vp_size.y - safe_bottom + 1.0:
			printerr("Button %s extends past bottom safe margin! Rect: %s, max_y: %f" % [b.name, rect, vp_size.y - safe_bottom])
			tc.queue_free()
			return false
	
	# 3. Verify NO two buttons overlap
	for i in range(buttons.size()):
		var b1 = buttons[i]
		var r1 = b1.get_global_rect()
		for j in range(i + 1, buttons.size()):
			var b2 = buttons[j]
			var r2 = b2.get_global_rect()
			if r1.intersects(r2):
				printerr("Overlap detected between %s and %s! Rect1: %v, Rect2: %v" % [b1.name, b2.name, r1, r2])
				tc.queue_free()
				return false
	
	print("  -> Resolution %4dx%4d: %d buttons verified, 0 overlaps, all >= 64px, safe area clean" % [res.x, res.y, buttons.size()])
	tc.queue_free()
	return true

func test_joystick_zone_and_following() -> bool:
	root.size = Vector2i(1920, 1080)
	await process_frame
	
	var tc: TouchControls = load("res://game/scenes/ui/mfw/TouchControls.tscn").instantiate()
	root.add_child(tc)
	await process_frame
	tc.apply_default_layout()
	
	var vp_size = tc.get_viewport_rect().size
	
	# Touch on the right half must never start the joystick (that side is for looking)
	var touch_right = InputEventScreenTouch.new()
	touch_right.index = 9
	touch_right.position = Vector2(vp_size.x * 0.6, vp_size.y * 0.5)
	touch_right.pressed = true
	tc._handle_screen_touch(touch_right)
	if tc._joystick_active:
		printerr("Joystick activated from a touch on the right half!")
		tc.queue_free()
		return false
	touch_right.pressed = false
	tc._handle_screen_touch(touch_right)

	# Anywhere on the left half (not on a button) starts the joystick, including high up (x=200, y=200)
	var touch_high = InputEventScreenTouch.new()
	touch_high.index = 10
	touch_high.position = Vector2(200, 200)
	touch_high.pressed = true
	tc._handle_screen_touch(touch_high)
	if not tc._joystick_active:
		printerr("Joystick did not start from a touch high on the left half!")
		tc.queue_free()
		return false
	touch_high.pressed = false
	tc._handle_screen_touch(touch_high)
	
	# Touch inside bottom-left joystick zone (e.g. x=160, y=850)
	var touch_inside = InputEventScreenTouch.new()
	touch_inside.index = 11
	touch_inside.position = Vector2(160, 850)
	touch_inside.pressed = true
	tc._handle_screen_touch(touch_inside)
	
	if not tc._joystick_active or tc._joystick_center != Vector2(160, 850):
		printerr("Joystick did not activate at thumb touch position!")
		tc.queue_free()
		return false
	
	# Following thumb drift: drag 120px to the right (> JOYSTICK_RADIUS 75px)
	var drag_drift = InputEventScreenDrag.new()
	drag_drift.index = 11
	drag_drift.position = Vector2(160 + 120, 850)
	tc._handle_screen_drag(drag_drift)
	
	# Center should have followed the thumb slightly (x > 160)
	if tc._joystick_center.x <= 160.0:
		printerr("Joystick center did not follow thumb drift!")
		tc.queue_free()
		return false
	
	# Release touch
	var touch_up = InputEventScreenTouch.new()
	touch_up.index = 11
	touch_up.pressed = false
	tc._handle_screen_touch(touch_up)
	
	if tc._joystick_active:
		printerr("Joystick stayed active after touch release!")
		tc.queue_free()
		return false
	
	tc.queue_free()
	return true

func test_sprint_lock() -> bool:
	root.size = Vector2i(1920, 1080)
	await process_frame
	
	var tc: TouchControls = load("res://game/scenes/ui/mfw/TouchControls.tscn").instantiate()
	root.add_child(tc)
	await process_frame
	tc.apply_default_layout()
	
	# Touch to start joystick at (180, 850)
	var touch_down = InputEventScreenTouch.new()
	touch_down.index = 5
	touch_down.position = Vector2(180, 850)
	touch_down.pressed = true
	tc._handle_screen_touch(touch_down)
	
	# Drag upward into sprint lock icon (e.g. y = 850 - 100 = 750, delta_y = -100 < -JOYSTICK_RADIUS * 1.15)
	var drag_lock = InputEventScreenDrag.new()
	drag_lock.index = 5
	drag_lock.position = Vector2(180, 740)
	tc._handle_screen_drag(drag_lock)
	
	if not tc._sprint_locked:
		printerr("Sprint lock did not engage when dragging upward into lock zone!")
		tc.queue_free()
		return false
	
	if not Input.is_action_pressed("move_forward") or not Input.is_action_pressed("sprint"):
		printerr("Sprint lock engaged but forward/sprint actions were not pressed!")
		tc.queue_free()
		return false
	
	# Release thumb: sprint lock MUST persist (auto-sprint without holding)
	var touch_up = InputEventScreenTouch.new()
	touch_up.index = 5
	touch_up.pressed = false
	tc._handle_screen_touch(touch_up)
	
	if not tc._sprint_locked:
		printerr("Sprint lock canceled immediately on thumb release! Must stay auto-sprinting.")
		tc.queue_free()
		return false
	
	if not Input.is_action_pressed("move_forward"):
		printerr("Auto-sprint stopped moving forward after thumb release!")
		tc.queue_free()
		return false
	
	# Tap joystick again to cancel sprint lock
	var tap_cancel = InputEventScreenTouch.new()
	tap_cancel.index = 6
	tap_cancel.position = Vector2(180, 850)
	tap_cancel.pressed = true
	tc._handle_screen_touch(tap_cancel)
	
	if tc._sprint_locked:
		printerr("Tapping joystick did not cancel sprint lock!")
		tc.queue_free()
		return false
	
	tc.queue_free()
	return true

func test_fire_buttons() -> bool:
	var tc: TouchControls = load("res://game/scenes/ui/mfw/TouchControls.tscn").instantiate()
	root.add_child(tc)
	await process_frame
	
	var left_fire = tc.left_fire_button
	var main_fire = tc.fire_button
	
	# 1. Left fire button press/release
	left_fire._press_button()
	if not Input.is_action_pressed("fire"):
		printerr("Left fire button did not press 'fire' action!")
		tc.queue_free()
		return false
	left_fire._release_button()
	if Input.is_action_pressed("fire"):
		printerr("Left fire button did not release 'fire' action!")
		tc.queue_free()
		return false
	
	# 2. Main fire button press/release
	main_fire._press_button()
	if not Input.is_action_pressed("fire"):
		printerr("Main fire button did not press 'fire' action!")
		tc.queue_free()
		return false
	main_fire._release_button()
	if Input.is_action_pressed("fire"):
		printerr("Main fire button did not release 'fire' action!")
		tc.queue_free()
		return false
	
	tc.queue_free()
	return true

func test_fire_and_drag_aiming() -> bool:
	var tc: TouchControls = load("res://game/scenes/ui/mfw/TouchControls.tscn").instantiate()
	root.add_child(tc)
	await process_frame
	
	var main_fire = tc.fire_button
	main_fire._press_button()
	
	if not Input.is_action_pressed("fire"):
		printerr("Main fire not pressed!")
		tc.queue_free()
		return false
	
	# Simulate dragging while holding fire button
	tc._accumulated_drag = Vector2.ZERO
	main_fire.touch_dragged.emit(Vector2(25.0, 10.0), 1)
	
	if tc._accumulated_drag == Vector2.ZERO:
		printerr("Fire button drag did not feed into look drag accumulator!")
		tc.queue_free()
		return false
	
	# Ensure fire is STILL held during drag
	if not Input.is_action_pressed("fire"):
		printerr("Fire action was released during fire-and-drag!")
		tc.queue_free()
		return false
	
	main_fire._release_button()
	tc.queue_free()
	return true

func test_combat_buttons() -> bool:
	var tc: TouchControls = load("res://game/scenes/ui/mfw/TouchControls.tscn").instantiate()
	root.add_child(tc)
	await process_frame
	
	# 1. Jump
	tc.jump_button._press_button()
	if not Input.is_action_pressed("jump"):
		printerr("Jump button failed")
		tc.queue_free()
		return false
	tc.jump_button._release_button()
	
	# 2. Reload
	tc.reload_button._press_button()
	if not Input.is_action_pressed("reload"):
		printerr("Reload button failed")
		tc.queue_free()
		return false
	tc.reload_button._release_button()
	
	# 3. Melee
	tc.melee_button._press_button()
	if not Input.is_action_pressed("melee"):
		printerr("Melee button failed")
		tc.queue_free()
		return false
	tc.melee_button._release_button()
	
	# 4. Block (Hold action)
	tc.block_button._press_button()
	if not Input.is_action_pressed("block"):
		printerr("Block button failed to hold")
		tc.queue_free()
		return false
	tc.block_button._release_button()
	if Input.is_action_pressed("block"):
		printerr("Block button did not release on lift")
		tc.queue_free()
		return false
	
	# 5. Crouch (Toggle mode)
	tc.crouch_button._press_button()
	if not Input.is_action_pressed("crouch"):
		printerr("Crouch toggle button did not press crouch")
		tc.queue_free()
		return false
	tc.crouch_button._release_button() # Releasing finger keeps toggled on
	if not Input.is_action_pressed("crouch"):
		printerr("Crouch toggle button released crouch prematurely!")
		tc.queue_free()
		return false
	tc.crouch_button._press_button() # Second tap toggles off
	if Input.is_action_pressed("crouch"):
		printerr("Crouch toggle button did not toggle off on second tap")
		tc.queue_free()
		return false
	
	tc.queue_free()
	return true

func test_interact_button() -> bool:
	var tc: TouchControls = load("res://game/scenes/ui/mfw/TouchControls.tscn").instantiate()
	root.add_child(tc)
	await process_frame
	
	# 1. Hidden when prompt is empty
	tc._on_prompt_changed("")
	if tc.interact_button.visible:
		printerr("Interact button visible with empty prompt!")
		tc.queue_free()
		return false
	
	# 2. Appears with dynamic text when prompt changes
	tc._on_prompt_changed("Hold [E] to rescue officer")
	if not tc.interact_button.visible:
		printerr("Interact button not visible with prompt!")
		tc.queue_free()
		return false
	if tc.interact_button.button_label_text != "RESCUE":
		printerr("Expected label RESCUE, got: ", tc.interact_button.button_label_text)
		tc.queue_free()
		return false
	
	tc._on_prompt_changed("Press [E] to pick up ammo")
	if tc.interact_button.button_label_text != "AMMO":
		printerr("Expected label AMMO, got: ", tc.interact_button.button_label_text)
		tc.queue_free()
		return false
	
	# 3. Holding interact presses "interact" action
	tc.interact_button._press_button()
	if not Input.is_action_pressed("interact"):
		printerr("Interact button press did not press 'interact' action!")
		tc.queue_free()
		return false
	tc.interact_button._release_button()
	if Input.is_action_pressed("interact"):
		printerr("Interact button did not release 'interact' action!")
		tc.queue_free()
		return false
	
	tc.queue_free()
	return true

func test_hud_customization_edit() -> bool:
	var tc: TouchControls = load("res://game/scenes/ui/mfw/TouchControls.tscn").instantiate()
	root.add_child(tc)
	await process_frame
	
	tc.enter_edit_mode()
	if not tc._is_edit_mode or not tc.edit_toolbar.visible:
		printerr("Edit mode did not activate toolbar!")
		tc.queue_free()
		return false
	
	# Test button selection and resize (0.6x to 1.5x, min 64px)
	var btn = tc.fire_button
	tc._select_button(btn)
	if tc._selected_button != btn:
		printerr("Failed to select button in edit mode")
		tc.queue_free()
		return false
	
	# Scale down to 0.6x
	tc._on_scale_slider_changed(0.6)
	if absf(btn.scale_factor - 0.6) > 0.01:
		printerr("Button scale factor was not set to 0.6!")
		tc.queue_free()
		return false
	if btn.size.x < 63.9 or btn.size.y < 63.9:
		printerr("Button shrunk below minimum 64px constraint after 0.6x resize!")
		tc.queue_free()
		return false
	
	# Scale up to 1.5x
	tc._on_scale_slider_changed(1.5)
	if absf(btn.scale_factor - 1.5) > 0.01:
		printerr("Button scale factor was not set to 1.5!")
		tc.queue_free()
		return false
	
	# Test opacity slider (20% to 100%)
	tc._on_opacity_slider_changed(0.4)
	if absf(tc.buttons_container.modulate.a - 0.4) > 0.01:
		printerr("Global opacity not updated to 0.4!")
		tc.queue_free()
		return false
	
	tc.exit_edit_mode()
	if tc._is_edit_mode or tc.edit_toolbar.visible:
		printerr("Edit mode toolbar remained visible after exit!")
		tc.queue_free()
		return false
	
	tc.queue_free()
	return true

func test_hud_customization_persistence() -> bool:
	var tc: TouchControls = load("res://game/scenes/ui/mfw/TouchControls.tscn").instantiate()
	root.add_child(tc)
	await process_frame
	
	tc.apply_default_layout()
	tc.fire_button.position = Vector2(500, 300)
	tc.fire_button.scale_factor = 1.25
	tc._global_opacity = 0.65
	
	# Save layout
	tc.save_layout_for_aspect_ratio()
	
	# Reset
	tc.apply_default_layout()
	if absf(tc.fire_button.scale_factor - 1.0) > 0.01:
		printerr("Reset default failed to restore scale factor!")
		tc.queue_free()
		return false
	
	# Reload from config
	tc.load_layout_for_aspect_ratio()
	if absf(tc.fire_button.scale_factor - 1.25) > 0.01:
		printerr("Failed to reload saved scale factor (1.25) from user://settings.cfg! Got: %f" % tc.fire_button.scale_factor)
		tc.queue_free()
		return false
	if absf(tc.buttons_container.modulate.a - 0.65) > 0.01:
		printerr("Failed to reload saved global opacity from config!")
		tc.queue_free()
		return false
	
	# Reset back to default for clean config
	tc.apply_default_layout()
	tc.save_layout_for_aspect_ratio()
	
	tc.queue_free()
	return true

func test_gyroscope_aim() -> bool:
	var im = root.get_node_or_null("InputManager")
	if not im:
		return false
	
	var sm = root.get_node_or_null("SettingsManager")
	if sm:
		sm.set_setting("gyro_mode", 0) # Off
		sm.set_setting("gyro_sensitivity", 1.0)
	
	# Inject mock gyroscope angular velocity (yaw = 2.0 rad/s, pitch = 1.0 rad/s)
	im.set_mock_gyroscope(Vector3(1.0, 2.0, 0.0), true)
	
	# 1. Mode 0 (Off): Gyro must NOT contribute to look delta
	var look_off = im.get_look_delta(0.016)
	if look_off != Vector2.ZERO:
		printerr("Gyroscope contributed look while gyro_mode is Off! Got: ", look_off)
		im.set_mock_gyroscope(Vector3.ZERO, false)
		return false
	
	# 2. Mode 1 (Always): Gyro contributes immediately
	if sm:
		sm.set_setting("gyro_mode", 1)
	var look_always = im.get_look_delta(0.016)
	if look_always == Vector2.ZERO:
		printerr("Gyroscope did not contribute look while gyro_mode is Always!")
		im.set_mock_gyroscope(Vector3.ZERO, false)
		return false
	
	# 3. Mode 2 (While firing): Only contributes when 'fire' is pressed
	if sm:
		sm.set_setting("gyro_mode", 2)
	Input.action_release("fire")
	var look_not_firing = im.get_look_delta(0.016)
	if look_not_firing != Vector2.ZERO:
		printerr("Gyroscope contributed look in While Firing mode without firing!")
		im.set_mock_gyroscope(Vector3.ZERO, false)
		return false
	
	Input.action_press("fire")
	var look_firing = im.get_look_delta(0.016)
	if look_firing == Vector2.ZERO:
		printerr("Gyroscope did not contribute look in While Firing mode while firing!")
		Input.action_release("fire")
		im.set_mock_gyroscope(Vector3.ZERO, false)
		return false
	Input.action_release("fire")
	
	# 4. Sensitivity test (double sensitivity = double look contribution)
	if sm:
		sm.set_setting("gyro_mode", 1)
		sm.set_setting("gyro_sensitivity", 1.0)
	var look_1x = im.get_look_delta(0.016)
	
	if sm:
		sm.set_setting("gyro_sensitivity", 2.0)
	var look_2x = im.get_look_delta(0.016)
	
	var ratio = look_2x.length() / maxf(look_1x.length(), 0.0001)
	if absf(ratio - 2.0) > 0.05:
		printerr("Gyro sensitivity scaling mismatch! Ratio: %f, expected 2.0" % ratio)
		im.set_mock_gyroscope(Vector3.ZERO, false)
		return false
	
	# Clean up mock gyro and reset setting to Off
	im.set_mock_gyroscope(Vector3.ZERO, false)
	if sm:
		sm.set_setting("gyro_mode", 0)
	
	return true
