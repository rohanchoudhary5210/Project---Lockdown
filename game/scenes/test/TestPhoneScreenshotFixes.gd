extends SceneTree

func _init() -> void:
	print("\n=== STARTING PHONE SCREENSHOT FIXES TEST SUITE ===")
	call_deferred("_run_all_tests")

func _run_all_tests() -> void:
	await TestServices.start(self)
	var passed = 0
	var failed = 0
	
	print("\n--- Test 1: Muzzle Flash Auto-Hide (Fast Shots, Reload, Pause, Respawn) ---")
	if await test_muzzle_flash():
		passed += 1
		print("PASSED: Test 1")
	else:
		failed += 1
		print("FAILED: Test 1")
	
	print("\n--- Test 2: Gun Ambient Lighting & Material on High and Low Quality ---")
	if await test_gun_ambient_lighting():
		passed += 1
		print("PASSED: Test 2")
	else:
		failed += 1
		print("FAILED: Test 2")
	
	print("\n--- Test 3: Viewmodel Camera FOV (65), Near (0.01), Rest Pose, SubViewport ---")
	if await test_viewmodel_camera_and_rest_pose():
		passed += 1
		print("PASSED: Test 3")
	else:
		failed += 1
		print("FAILED: Test 3")
	
	print("\n--- Test 4: Draw Order (Viewmodel Below HUD, Subtitles, Menus) ---")
	if await test_draw_order():
		passed += 1
		print("PASSED: Test 4")
	else:
		failed += 1
		print("FAILED: Test 4")
	
	print("\n--- Test 5: CanvasLayer Anchors (Crosshair, Pause Menu, Death Screen Centered & Fullscreen at 1920x1080, 2400x1080, 2560x1080) ---")
	if await test_crosshair_centered():
		passed += 1
		print("PASSED: Test 5")
	else:
		failed += 1
		print("FAILED: Test 5")
	
	print("\n--- Test 6: HUD Safe Area Margins (>= 24px, HP & Ammo Not Cut Off) ---")
	if await test_safe_area_margins():
		passed += 1
		print("PASSED: Test 6")
	else:
		failed += 1
		print("FAILED: Test 6")
	
	print("\n=======================================================")
	print("RESULTS: %d Passed, %d Failed" % [passed, failed])
	print("=======================================================")
	
	if failed == 0:
		print("ALL PHONE SCREENSHOT FIXES VERIFIED SUCCESSFULLY!\n")
		quit(0)
	else:
		print("SOME TESTS FAILED!\n")
		quit(1)

func test_muzzle_flash() -> bool:
	var vis_scene = load("res://game/scenes/gameplay/weapons/PistolVisual.tscn")
	if not vis_scene:
		printerr("Could not load pistol_visual.tscn")
		return false
	
	var vis: PistolVisual = vis_scene.instantiate()
	root.add_child(vis)
	await process_frame
	
	var mesh = vis.get_node("MuzzleFlash/FlashMesh") as MeshInstance3D
	var light = vis.get_node("MuzzleFlash/FlashLight") as OmniLight3D
	
	# Initial: must be hidden
	if mesh.visible or light.visible:
		printerr("Initial muzzle flash is visible!")
		vis.queue_free()
		return false
	
	# Trigger flash
	vis.trigger_muzzle_flash(0.04)
	if not mesh.visible or not light.visible:
		printerr("Muzzle flash did not appear on trigger!")
		vis.queue_free()
		return false
	
	# Advance 0.02s: should still be visible
	vis._process(0.02)
	if not mesh.visible or not light.visible:
		printerr("Muzzle flash disappeared prematurely before 0.04s!")
		vis.queue_free()
		return false
	
	# Advance another 0.03s (total 0.05s > 0.04s): must auto-hide
	vis._process(0.03)
	if mesh.visible or light.visible:
		printerr("Muzzle flash stayed visible after 0.04s!")
		vis.queue_free()
		return false
	
	# Test rapid shooting: trigger, advance 0.02s, trigger again, advance 0.03s (still visible), advance 0.02s (hidden)
	vis.trigger_muzzle_flash(0.04)
	vis._process(0.02)
	vis.trigger_muzzle_flash(0.04) # Rapid follow-up shot
	vis._process(0.03)
	if not mesh.visible or not light.visible:
		printerr("Rapid second shot flash was cut short by first shot timer!")
		vis.queue_free()
		return false
	vis._process(0.02)
	if mesh.visible or light.visible:
		printerr("Rapid second shot flash did not hide after duration!")
		vis.queue_free()
		return false
	
	# Test reload cancels flash
	vis.trigger_muzzle_flash(0.04)
	vis.hide_muzzle_flash()
	if mesh.visible or light.visible:
		printerr("hide_muzzle_flash did not hide flash!")
		vis.queue_free()
		return false
	
	# Test pause hides flash
	vis.trigger_muzzle_flash(0.04)
	vis._on_pause_toggled(true)
	if mesh.visible or light.visible:
		printerr("Pause did not immediately hide muzzle flash!")
		vis.queue_free()
		return false
	
	# Test respawn hides flash
	vis.trigger_muzzle_flash(0.04)
	vis._on_player_respawned()
	if mesh.visible or light.visible:
		printerr("Respawn did not immediately hide muzzle flash!")
		vis.queue_free()
		return false
	
	vis.queue_free()
	return true

func test_gun_ambient_lighting() -> bool:
	var player_scene = load("res://game/scenes/gameplay/player/Player.tscn")
	if not player_scene:
		return false
	
	var player = player_scene.instantiate()
	root.add_child(player)
	await process_frame
	
	var vm_cam: ViewmodelCamera = player.find_child("ViewmodelCamera", true, false)
	if not vm_cam:
		printerr("ViewmodelCamera not found")
		player.queue_free()
		return false
	
	var env = vm_cam.environment
	if not env:
		printerr("ViewmodelCamera has no Environment!")
		player.queue_free()
		return false
	
	if env.ambient_light_source != Environment.AMBIENT_SOURCE_COLOR:
		printerr("Viewmodel ambient_light_source is not AMBIENT_SOURCE_COLOR: ", env.ambient_light_source)
		player.queue_free()
		return false
	
	if env.ambient_light_energy <= 0.0:
		printerr("Viewmodel ambient_light_energy is 0 (pure black)!")
		player.queue_free()
		return false
	
	# BG_KEEP never clears the overlay, which left the muzzle flash stuck on screen
	if env.background_mode != Environment.BG_CLEAR_COLOR:
		printerr("Viewmodel must clear every frame (BG_CLEAR_COLOR), got background_mode ", env.background_mode)
		player.queue_free()
		return false
	
	var sub_vp = player.find_child("SubViewport", true, false) as SubViewport
	if sub_vp and sub_vp.positional_shadow_atlas_size != 0:
		printerr("SubViewport has shadow atlas enabled: ", sub_vp.positional_shadow_atlas_size)
		player.queue_free()
		return false
	
	# Test material quality switching (Low vs High) does not overwrite gunmetal
	var sm = TestServices.get_service(self, &"settings")
	if sm:
		sm.set_setting("graphics_quality", "Low")
		var pistol_mesh = player.find_child("Receiver", true, false) as MeshInstance3D
		if pistol_mesh and pistol_mesh.material_override != null:
			printerr("Low quality erroneously overrode gunmetal material on weapon layer 2!")
			sm.set_setting("graphics_quality", "High")
			player.queue_free()
			return false
		sm.set_setting("graphics_quality", "High")
	
	player.queue_free()
	return true

func test_viewmodel_camera_and_rest_pose() -> bool:
	var player_scene = load("res://game/scenes/gameplay/player/Player.tscn")
	var player = player_scene.instantiate()
	root.add_child(player)
	await process_frame
	
	var vm_cam: ViewmodelCamera = player.find_child("ViewmodelCamera", true, false)
	if not vm_cam:
		player.queue_free()
		return false
	
	if absf(vm_cam.fov - 65.0) > 0.01:
		printerr("ViewmodelCamera FOV is %f, expected fixed 65.0!" % vm_cam.fov)
		player.queue_free()
		return false
	
	if absf(vm_cam.near - 0.01) > 0.001:
		printerr("ViewmodelCamera near plane is %f, expected 0.01!" % vm_cam.near)
		player.queue_free()
		return false
	
	# Recoil rest pose recovery test
	var weapon: WeaponController = player.find_child("Pistol", true, false)
	if weapon:
		weapon._recoil_pos_offset = Vector3(0.01, 0.02, 0.05)
		weapon._recoil_rot_offset = Vector3(0.1, 0.05, 0.0)
		# Process recovery over 0.5s
		for i in range(30):
			weapon._update_viewmodel_recoil(0.016)
		
		if weapon._recoil_pos_offset != Vector3.ZERO or weapon._recoil_rot_offset != Vector3.ZERO:
			printerr("Weapon recoil did not fully snap to rest pose (0,0,0)!")
			player.queue_free()
			return false
	
	player.queue_free()
	return true

func test_draw_order() -> bool:
	var player_scene = load("res://game/scenes/gameplay/player/Player.tscn")
	var player = player_scene.instantiate()
	root.add_child(player)
	await process_frame
	
	var vm_layer = player.get_node("ViewmodelLayer") as CanvasLayer
	if not vm_layer:
		printerr("ViewmodelLayer not found")
		player.queue_free()
		return false
	
	# Must be drawn below all HUD, subtitles, touch controls and menus (which are on layer >= 0)
	if vm_layer.layer >= 0:
		printerr("ViewmodelLayer layer is %d! Must be < 0 (e.g. -1) to render below HUD." % vm_layer.layer)
		player.queue_free()
		return false
	
	player.queue_free()
	return true

func test_crosshair_centered() -> bool:
	var level_scene = load("res://game/scenes/gameplay/levels/Floor01.tscn")
	var level = level_scene.instantiate()
	root.add_child(level)
	await process_frame
	
	var hud = level.find_child("HUD", true, false)
	if not hud:
		printerr("HUD not found in floor_01!")
		level.queue_free()
		return false
	
	# Verify HUD sits inside CanvasLayer at layer 0
	var hud_parent = hud.get_parent()
	if not (hud_parent is CanvasLayer):
		printerr("HUD parent is not a CanvasLayer! Found: ", hud_parent)
		level.queue_free()
		return false
	if hud_parent.layer != 0:
		printerr("CanvasLayer layer is %d, expected 0!" % hud_parent.layer)
		level.queue_free()
		return false
	
	# Verify HUD root is full rect
	if hud.anchors_preset != Control.PRESET_FULL_RECT and (hud.anchor_right != 1.0 or hud.anchor_bottom != 1.0):
		printerr("HUD root anchors are not full rect! preset=%d, right=%f, bottom=%f" % [hud.anchors_preset, hud.anchor_right, hud.anchor_bottom])
		level.queue_free()
		return false
	
	var crosshair = hud.get_node("Crosshair") as Control
	var pause_menu = hud.get_node("PauseMenu") as PauseMenu
	var death_container = hud.get_node("DeathContainer") as Control
	var death_vbox = death_container.get_node("Center/VBox") as Control
	var menu_panel = pause_menu.get_node("%MenuPanel/Panel") as Control
	var touch_controls = hud.get_node_or_null("TouchControls") as Control
	
	var resolutions = [
		Vector2i(1920, 1080), # 16:9 standard
		Vector2i(2400, 1080), # 20:9 phone
		Vector2i(2560, 1080)  # 21:9 ultrawide
	]
	
	for res in resolutions:
		root.size = res
		await process_frame
		hud._update_layout_and_safe_area()
		
		var vp_rect = hud.get_viewport_rect()
		var expected_center = vp_rect.size * 0.5
		
		# 1. Crosshair centering
		var diff = crosshair.position - expected_center
		if diff.length() > 0.5:
			printerr("Crosshair not centered at res %v! Pos: %v, Expected: %v" % [res, crosshair.position, expected_center])
			level.queue_free()
			return false
		
		# 2. Pause Menu full screen & center check
		pause_menu.open_menu()
		await process_frame
		await process_frame
		if (pause_menu.size - vp_rect.size).length() > 1.0:
			printerr("PauseMenu not full screen at res %v! Size: %v, Expected: %v" % [res, pause_menu.size, vp_rect.size])
			level.queue_free()
			return false
		var pm_center = menu_panel.global_position + menu_panel.size * 0.5
		if (pm_center - expected_center).length() > 1.0:
			printerr("PauseMenu panel not centered at res %v! Pos: %v, Expected: %v" % [res, pm_center, expected_center])
			level.queue_free()
			return false
		pause_menu.close_menu()
		
		# 3. Death Screen full screen & center check
		death_container.visible = true
		await process_frame
		await process_frame
		if (death_container.size - vp_rect.size).length() > 1.0:
			printerr("DeathContainer not full screen at res %v! Size: %v, Expected: %v" % [res, death_container.size, vp_rect.size])
			level.queue_free()
			return false
		var death_center = death_vbox.global_position + death_vbox.size * 0.5
		if (death_center - expected_center).length() > 1.0:
			printerr("DeathContainer VBox not centered at res %v! Pos: %v, Expected: %v" % [res, death_center, expected_center])
			level.queue_free()
			return false
		death_container.visible = false
		
		# 4. TouchControls full screen check
		if touch_controls:
			if (touch_controls.size - vp_rect.size).length() > 1.0:
				printerr("TouchControls not full screen at res %v! Size: %v, Expected: %v" % [res, touch_controls.size, vp_rect.size])
				level.queue_free()
				return false
		
		print("  -> Resolution %4dx%4d: Crosshair=%v, PauseMenu=%v, DeathScreen=%v [ALL CENTERED]" % [
			res.x, res.y, crosshair.position, pm_center, death_center
		])
	
	level.queue_free()
	return true

func test_safe_area_margins() -> bool:
	var hud_scene = load("res://game/scenes/ui/mfw/Hud.tscn")
	var hud = hud_scene.instantiate()
	root.add_child(hud)
	await process_frame
	
	hud._update_layout_and_safe_area()
	
	var hp_container = hud.get_node("HealthContainer") as Control
	var ammo_container = hud.get_node("AmmoContainer") as Control
	var hp_label = hud.find_child("HealthLabel", true, false) as Label
	
	if hp_container.offset_left < 24.0:
		printerr("HealthContainer left margin %f is less than required 24px!" % hp_container.offset_left)
		hud.queue_free()
		return false
	
	if hp_container.offset_bottom > -24.0:
		printerr("HealthContainer bottom margin %f is less than required 24px!" % hp_container.offset_bottom)
		hud.queue_free()
		return false
	
	if ammo_container.offset_right > -24.0:
		printerr("AmmoContainer right margin %f is less than required 24px!" % ammo_container.offset_right)
		hud.queue_free()
		return false
	
	if not hp_label or hp_label.text.is_empty():
		printerr("HealthLabel is missing or empty!")
		hud.queue_free()
		return false
	
	hud.queue_free()
	return true
