extends SceneTree

func _init() -> void:
	print("\n=== STARTING MOBILE FIXES TEST SUITE ===")
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	var passed = 0
	var failed = 0
	
	print("\n--- Test 1: Pause Button Dimensions and Position ---")
	if await test_pause_button_dimensions_and_position():
		passed += 1
		print("PASSED: Test 1")
	else:
		failed += 1
		print("FAILED: Test 1")
	
	print("\n--- Test 2: Android Back Button (NOTIFICATION_WM_GO_BACK_REQUEST) ---")
	if await test_android_back_button():
		passed += 1
		print("PASSED: Test 2")
	else:
		failed += 1
		print("FAILED: Test 2")
	
	print("\n--- Test 3: Auto-Pause on Background / Focus Loss ---")
	if await test_auto_pause_on_focus_loss():
		passed += 1
		print("PASSED: Test 3")
	else:
		failed += 1
		print("FAILED: Test 3")
	
	print("\n--- Test 4: Touch Controls Hidden & Disabled When Paused ---")
	if await test_touch_controls_hidden_when_paused():
		passed += 1
		print("PASSED: Test 4")
	else:
		failed += 1
		print("FAILED: Test 4")
	
	print("\n--- Test 5: Mouse Capture & Tap-To-Resume Disabled on Touch ---")
	if await test_touch_device_mouse_capture():
		passed += 1
		print("PASSED: Test 5")
	else:
		failed += 1
		print("FAILED: Test 5")
	
	print("\n--- Test 6: Recoil Scaling on Touch vs Mouse ---")
	if await test_recoil_scaling():
		passed += 1
		print("PASSED: Test 6")
	else:
		failed += 1
		print("FAILED: Test 6")
	
	print("\n--- Test 7: Touch Recoil Auto-Recovery Over ~0.25s ---")
	if await test_recoil_auto_recovery():
		passed += 1
		print("PASSED: Test 7")
	else:
		failed += 1
		print("FAILED: Test 7")
	
	print("\n--- Test 8: SettingsManager Touch Recoil Persistence ---")
	if await test_settings_persistence():
		passed += 1
		print("PASSED: Test 8")
	else:
		failed += 1
		print("FAILED: Test 8")
	
	print("\n==========================================")
	print("RESULTS: %d Passed, %d Failed" % [passed, failed])
	print("==========================================")
	
	if failed == 0:
		print("ALL MOBILE FIXES TESTS PASSED!\n")
		quit(0)
	else:
		print("SOME TESTS FAILED!\n")
		quit(1)

func test_pause_button_dimensions_and_position() -> bool:
	var sm = root.get_node_or_null("SettingsManager")
	if sm:
		sm.set_setting("touch_controls_mode", 1) # Enable touch controls
	
	var scene = load("res://scenes/ui/touch_controls.tscn")
	if not scene:
		printerr("Could not load touch_controls.tscn")
		return false
	
	var tc = scene.instantiate()
	root.add_child(tc)
	await create_timer(0.05).timeout
	
	var pause_btn: TouchButton = tc.get_node_or_null("%PauseButton")
	if not pause_btn:
		printerr("PauseButton not found in touch_controls")
		tc.queue_free()
		return false
	
	# Minimum size must be at least 64x64
	var min_sz = pause_btn.custom_minimum_size
	if min_sz.x < 64.0 or min_sz.y < 64.0:
		printerr("PauseButton minimum size (%v) is less than 64x64!" % min_sz)
		tc.queue_free()
		return false
	
	# Must be located in top-left
	if pause_btn.offset_left < 0 or pause_btn.offset_left > 100 or pause_btn.offset_top < 0 or pause_btn.offset_top > 100:
		printerr("PauseButton is not in the top-left corner! Pos: (%f, %f)" % [pause_btn.offset_left, pause_btn.offset_top])
		tc.queue_free()
		return false
	
	# Verify that touching pause button returns true for _is_touch_on_any_button
	var pause_center = pause_btn.get_global_rect().get_center()
	if not tc._is_touch_on_any_button(pause_center):
		printerr("PauseButton center %v not recognized by _is_touch_on_any_button!" % pause_center)
		tc.queue_free()
		return false
	
	# Verify that touch on pause button does NOT activate floating joystick
	var touch_ev = InputEventScreenTouch.new()
	touch_ev.position = pause_center
	touch_ev.pressed = true
	touch_ev.index = 99
	tc._handle_screen_touch(touch_ev)
	if tc._joystick_active:
		printerr("Tapping pause button erroneously activated joystick!")
		tc.queue_free()
		return false
	
	tc.queue_free()
	if sm:
		sm.set_setting("touch_controls_mode", 0)
	return true

func test_android_back_button() -> bool:
	var im = root.get_node_or_null("InputManager")
	if not im:
		printerr("InputManager autoload not found")
		return false
	
	# Verify quit-on-go-back disabled
	# InputManager sets get_tree().set_auto_accept_quit(false) in _ready()
	
	# Ensure unpaused initially
	im.resume_gameplay()
	if im.is_gameplay_paused:
		printerr("Failed to resume gameplay initially")
		return false
	
	# Simulate back button notification
	im.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	if not im.is_gameplay_paused:
		printerr("NOTIFICATION_WM_GO_BACK_REQUEST did not pause gameplay!")
		return false
	
	# Simulate back button notification again to resume
	im.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	if im.is_gameplay_paused:
		printerr("Second NOTIFICATION_WM_GO_BACK_REQUEST did not resume gameplay!")
		return false
	
	return true

func test_auto_pause_on_focus_loss() -> bool:
	var im = root.get_node_or_null("InputManager")
	if not im:
		return false
	
	im.resume_gameplay()
	if im.is_gameplay_paused:
		return false
	
	# Test NOTIFICATION_APPLICATION_PAUSED
	im.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	if not im.is_gameplay_paused:
		printerr("NOTIFICATION_APPLICATION_PAUSED did not pause gameplay!")
		return false
	
	im.resume_gameplay()
	
	# Test NOTIFICATION_WM_WINDOW_FOCUS_OUT
	im.notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	if not im.is_gameplay_paused:
		printerr("NOTIFICATION_WM_WINDOW_FOCUS_OUT did not pause gameplay!")
		return false
	
	im.resume_gameplay()
	return true

func test_touch_controls_hidden_when_paused() -> bool:
	var scene = load("res://scenes/ui/touch_controls.tscn")
	var tc = scene.instantiate()
	root.add_child(tc)
	await create_timer(0.05).timeout
	
	# Simulate pressing fire
	Input.action_press("fire")
	tc.fire_button.is_pressed = true
	
	# Pause touch controls
	tc.set_paused(true)
	
	if tc.visible:
		printerr("Touch controls still visible when paused!")
		tc.queue_free()
		return false
	
	if tc.is_processing_input():
		printerr("Touch controls still processing input when paused!")
		tc.queue_free()
		return false
	
	if tc.fire_button.is_pressed:
		printerr("Touch buttons were not force-released when paused!")
		tc.queue_free()
		return false
	
	# Unpause
	tc.set_paused(false)
	tc.queue_free()
	return true

func test_touch_device_mouse_capture() -> bool:
	var im = root.get_node_or_null("InputManager")
	var sm = root.get_node_or_null("SettingsManager")
	if not im or not sm:
		return false
	
	# Set touch mode to 1 (forced touch / debug)
	sm.set_setting("touch_controls_mode", 1)
	if not im.is_touch_device():
		printerr("InputManager failed to detect touch device with mode=1")
		return false
	
	# Capture mouse should NOT set mouse mode to CAPTURED on touch devices
	im.capture_mouse()
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		printerr("Input.mouse_mode was set to MOUSE_MODE_CAPTURED on touch device!")
		return false
	
	# Now pause the game
	im.pause_gameplay()
	if not im.is_gameplay_paused:
		printerr("pause_gameplay failed")
		return false
	
	# Simulate a screen tap (mouse click emulation)
	var click_ev = InputEventMouseButton.new()
	click_ev.button_index = MOUSE_BUTTON_LEFT
	click_ev.pressed = true
	click_ev.position = Vector2(400, 300)
	
	im._input(click_ev)
	if not im.is_gameplay_paused:
		printerr("Screen tap resumed game on touch device! Screen tap must NEVER resume.")
		return false
	
	# Now resume via resume_gameplay() (as ResumeButton does)
	im.resume_gameplay()
	if im.is_gameplay_paused:
		printerr("resume_gameplay failed to resume")
		return false
	
	# Restore touch controls mode
	sm.set_setting("touch_controls_mode", 0)
	return true

func test_recoil_scaling() -> bool:
	var im = root.get_node_or_null("InputManager")
	var sm = root.get_node_or_null("SettingsManager")
	var pistol_data = load("res://data/pistol_data.tres") as WeaponData
	if not pistol_data:
		printerr("Could not load pistol_data.tres")
		return false
	
	if not ("recoil_multiplier_touch" in pistol_data):
		printerr("recoil_multiplier_touch missing on WeaponData")
		return false
	
	if pistol_data.recoil_multiplier_touch != 0.45:
		printerr("recoil_multiplier_touch expected 0.45, got %f" % pistol_data.recoil_multiplier_touch)
		return false
	
	# Set touch recoil in settings to 0.45
	sm.set_setting("touch_recoil", 0.45)
	
	# Case A: Input device is MOUSE_KEYBOARD
	sm.set_setting("touch_controls_mode", 2) # Off
	im.last_input_device = im.InputDevice.MOUSE_KEYBOARD
	if im.is_last_input_touch():
		printerr("is_last_input_touch returned true for MOUSE_KEYBOARD")
		return false
	
	# Case B: Input device is TOUCH
	sm.set_setting("touch_controls_mode", 1) # Touch
	im.last_input_device = im.InputDevice.TOUCH
	if not im.is_last_input_touch():
		printerr("is_last_input_touch returned false for TOUCH")
		return false
	
	# Reset
	sm.set_setting("touch_controls_mode", 0)
	return true

func test_recoil_auto_recovery() -> bool:
	var player_scene = load("res://scenes/player/player.tscn")
	if not player_scene:
		printerr("Could not load player.tscn")
		return false
	
	var player: PlayerController = player_scene.instantiate()
	root.add_child(player)
	await create_timer(0.05).timeout
	
	player._pitch = 0.0
	player.camera_pivot.rotation.x = 0.0
	player.camera_pivot.rotation.y = 0.0
	
	var kick_pitch: float = 0.035 * 0.45 # 0.01575
	var kick_yaw: float = 0.01 * 0.45   # 0.0045
	
	# Apply touch recoil
	player.apply_camera_recoil(kick_pitch, kick_yaw, true)
	
	# Immediately after kick: pitch must be kicked up
	if absf(player._pitch - kick_pitch) > 0.0001:
		printerr("Player pitch not kicked up immediately! Expected %f, got %f" % [kick_pitch, player._pitch])
		player.queue_free()
		return false
	
	# Advance physics by 0.125s (half of 0.25s recovery time)
	player._physics_process(0.125)
	var expected_half = kick_pitch * 0.5
	if player._pitch <= 0.001 or player._pitch >= kick_pitch:
		printerr("Player pitch did not smoothly recover halfway! Got %f" % player._pitch)
		player.queue_free()
		return false
	
	# Advance physics by another 0.13s (total > 0.25s)
	player._physics_process(0.13)
	if absf(player._pitch) > 0.0001:
		printerr("Player pitch did not fully recover back to 0.0 after 0.25s! Got %f" % player._pitch)
		player.queue_free()
		return false
	
	if absf(player.camera_pivot.rotation.y) > 0.0001:
		printerr("Player camera_pivot yaw did not fully recover! Got %f" % player.camera_pivot.rotation.y)
		player.queue_free()
		return false
	
	# Now test mouse kick: must NOT auto-recover!
	player._pitch = 0.0
	player.camera_pivot.rotation.x = 0.0
	player.apply_camera_recoil(0.035, 0.0, false)
	player._physics_process(0.3)
	if absf(player._pitch - 0.035) > 0.0001:
		printerr("Mouse recoil incorrectly auto-recovered! Expected 0.035, got %f" % player._pitch)
		player.queue_free()
		return false
	
	player.queue_free()
	return true

func test_settings_persistence() -> bool:
	var sm = root.get_node_or_null("SettingsManager")
	if not sm:
		return false
	
	sm.set_setting("touch_recoil", 0.70)
	if absf(sm.touch_recoil - 0.70) > 0.001:
		printerr("SettingsManager touch_recoil not updated")
		return false
	
	# Verify config file on disk
	var cfg = ConfigFile.new()
	var err = cfg.load("user://settings.cfg")
	if err != OK:
		printerr("Could not load user://settings.cfg")
		return false
	
	var val = cfg.get_value("controls", "touch_recoil", -1.0)
	if absf(val - 0.70) > 0.001:
		printerr("touch_recoil in user://settings.cfg expected 0.70, got %f" % val)
		return false
	
	# Restore default
	sm.set_setting("touch_recoil", 0.45)
	return true
