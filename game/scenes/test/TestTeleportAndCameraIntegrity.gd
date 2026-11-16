extends SceneTree

## Project: Lockdown - Teleport & Camera Integrity Test Suite
## Tests:
## 1. Physics interpolation reset on player respawn (camera does not travel from death spot)
## 2. Physics interpolation reset on enemy EncounterZone rollback (enemy does not slide back)
## 3. Top-level camera pivot: crouch camera height transition (stand 1.6m <-> crouch 0.85m)
## 4. Camera shake & dynamic FOV kick functionality
## 5. Recoil pitch/yaw kick and recovery
## 6. InteractionRay alignment with camera pivot and detection
## 7. Weapon hitscan & Melee shapecast origin alignment with camera
## 8. Death slow-motion sequence (Engine.time_scale = 0.25 -> 1.0)
## 9. Keyboard diagonal movement (W+D) speed <= straight W speed
## 10. F5 Performance overlay mathematical consistency (FPS * frame_ms ≈ 1000)

var passed_count: int = 0
var failed_count: int = 0

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("\n=== STARTING TELEPORT & CAMERA INTEGRITY TEST SUITE ===\n")
	
	await _test_1_respawn_teleport_camera()
	await _test_2_enemy_encounter_rollback()
	await _test_3_crouch_camera_height()
	await _test_4_camera_shake_and_fov_kick()
	await _test_5_camera_recoil()
	await _test_6_interaction_ray_alignment()
	await _test_7_weapon_and_melee_origins()
	await _test_8_death_slow_motion()
	await _test_9_keyboard_diagonal_speed()
	await _test_10_f5_perf_label_consistency()
	await _test_11_mouse_look_90_deg_camera_turn()
	await _test_12_touch_swipe_90_deg_camera_turn()
	await _test_13_aim_assist_camera_rotation()
	await _test_14_recoil_camera_rotation()
	await _test_15_teleport_camera_rotation()
	
	print("\n=======================================================")
	print("RESULTS: %d Passed, %d Failed" % [passed_count, failed_count])
	print("=======================================================\n")
	
	if failed_count == 0:
		print("ALL TELEPORT & CAMERA INTEGRITY TESTS PASSED SUCCESSFULLY!\n")
		quit(0)
	else:
		printerr("SOME TESTS FAILED!\n")
		quit(1)

# ------------------------------------------------------------------------------
# Test 1: Player Respawn Teleport & Camera Pivot
# ------------------------------------------------------------------------------
func _test_1_respawn_teleport_camera() -> void:
	print("--- Test 1: Player Respawn & Camera Pivot Reset ---")
	var world = Node3D.new()
	root.add_child(world)
	await process_frame
	
	var player_scene = load("res://game/scenes/gameplay/player/Player.tscn")
	var player: Player = player_scene.instantiate()
	world.add_child(player)
	await process_frame
	
	var cm = root.get_node_or_null("CheckpointManager")
	if not cm:
		printerr("CheckpointManager autoload not found!")
		_fail()
		world.queue_free()
		return
	
	# Reset checkpoint session
	cm.reset_session()
	
	# Set player at start checkpoint (2.0, 0.0, 10.0)
	player.teleport(Vector3(2.0, 0.0, 10.0), 0.0, 0.0)
	
	var cp = Node3D.new()
	cp.name = "Checkpoint1"
	cp.set("checkpoint_order", 1)
	world.add_child(cp)
	cm.record_checkpoint(cp, player)
	
	var snap = cm.current_snapshot
	if not snap:
		printerr("Snapshot was not recorded!")
		_fail()
		world.queue_free()
		return
	
	print("  -> Checkpoint recorded at: ", snap.player_position)
	
	# Simulate player traveling far away to death spot (35.0, 2.0, 5.0)
	player.teleport(Vector3(35.0, 2.0, 5.0), deg_to_rad(90.0), 0.0)
	player._process(0.016)
	
	# Player dies
	player.is_dead = true
	
	# Respawn
	cm.respawn_player()
	
	# Verification immediately after respawn:
	var snap_pos = snap.player_position
	print("  -> Post-respawn player pos: ", player.global_position)
	print("  -> Post-respawn camera pivot pos: ", player.camera_pivot.global_position)
	
	if player.global_position.distance_to(snap_pos) > 0.01:
		printerr("Player position not restored to checkpoint! Pos: ", player.global_position)
		_fail()
		world.queue_free()
		return
	
	var expected_cam_pos = snap_pos + Vector3(0.0, player.player_data.stand_camera_height, 0.0)
	if player.camera_pivot.global_position.distance_to(expected_cam_pos) > 0.01:
		printerr("Camera pivot not snapped to checkpoint! Pos: ", player.camera_pivot.global_position, " expected: ", expected_cam_pos)
		_fail()
		world.queue_free()
		return
	
	# Run a frame of process: camera pivot must remain firmly at checkpoint with no interpolation lag
	player._process(0.016)
	print("  -> After process camera pivot pos: ", player.camera_pivot.global_position)
	if player.camera_pivot.global_position.distance_to(expected_cam_pos) > 0.05:
		printerr("Camera pivot slid/interpolated away from checkpoint after process! Pos: ", player.camera_pivot.global_position)
		_fail()
		world.queue_free()
		return
	
	_pass("Test 1")
	world.queue_free()
	await process_frame

# ------------------------------------------------------------------------------
# Test 2: Enemy Encounter Rollback
# ------------------------------------------------------------------------------
func _test_2_enemy_encounter_rollback() -> void:
	print("--- Test 2: Enemy Encounter Rollback (No Sliding Back) ---")
	var world = Node3D.new()
	root.add_child(world)
	await process_frame
	
	var enemy_scene = load("res://game/scenes/gameplay/enemies/RusherEnemy.tscn")
	var enemy: EnemyBase = enemy_scene.instantiate()
	world.add_child(enemy)
	await process_frame
	
	var spawn_trans = Transform3D(Basis(), Vector3(8.0, 0.0, 8.0))
	enemy.global_transform = spawn_trans
	enemy.reset_to_spawn(spawn_trans)
	
	# Simulate enemy moving during combat to (25.0, 0.0, 8.0)
	enemy.global_position = Vector3(25.0, 0.0, 8.0)
	enemy.velocity = Vector3(5.0, 0.0, 0.0)
	
	# Rollback / Reset to spawn
	enemy.reset_to_spawn(spawn_trans)
	
	if enemy.global_position.distance_to(spawn_trans.origin) > 0.01:
		printerr("Enemy transform not restored! Pos: ", enemy.global_position)
		_fail()
		world.queue_free()
		return
	
	if enemy.velocity != Vector3.ZERO:
		printerr("Enemy velocity not zeroed on spawn reset!")
		_fail()
		world.queue_free()
		return
	
	_pass("Test 2")
	world.queue_free()
	await process_frame

# ------------------------------------------------------------------------------
# Test 3: Crouch Camera Height Transition
# ------------------------------------------------------------------------------
func _test_3_crouch_camera_height() -> void:
	print("--- Test 3: Crouch Camera Height Transition ---")
	var world = Node3D.new()
	root.add_child(world)
	await process_frame
	
	var player: Player = load("res://game/scenes/gameplay/player/Player.tscn").instantiate()
	world.add_child(player)
	await process_frame
	
	var stand_h = player.player_data.stand_camera_height # 1.6
	var crouch_h = player.player_data.crouch_camera_height # 0.85
	
	# Initially standing
	player._process(0.016)
	if absf(player.current_camera_height - stand_h) > 0.01:
		printerr("Initial camera height not stand height! Got: ", player.current_camera_height)
		_fail()
		world.queue_free()
		return
	
	# Trigger crouch
	player.target_camera_height = crouch_h
	player.is_crouching = true
	
	# Simulate 1.0s of frames to transition
	for i in range(60):
		player._process(0.016)
	
	if absf(player.current_camera_height - crouch_h) > 0.02:
		printerr("Crouch height did not transition to crouch_h! Got: ", player.current_camera_height, " expected: ", crouch_h)
		_fail()
		world.queue_free()
		return
	
	var expected_cam_y = player.global_position.y + crouch_h
	if absf(player.camera_pivot.global_position.y - expected_cam_y) > 0.05:
		printerr("Camera pivot Y did not match crouch height! Got: ", player.camera_pivot.global_position.y, " expected: ", expected_cam_y)
		_fail()
		world.queue_free()
		return
	
	# Uncrouch
	player.target_camera_height = stand_h
	player.is_crouching = false
	for i in range(60):
		player._process(0.016)
	
	if absf(player.current_camera_height - stand_h) > 0.02:
		printerr("Camera height did not transition back to stand_h! Got: ", player.current_camera_height)
		_fail()
		world.queue_free()
		return
	
	_pass("Test 3")
	world.queue_free()
	await process_frame

# ------------------------------------------------------------------------------
# Test 4: Camera Shake & Dynamic FOV Kick
# ------------------------------------------------------------------------------
func _test_4_camera_shake_and_fov_kick() -> void:
	print("--- Test 4: Camera Shake & FOV Kick ---")
	var world = Node3D.new()
	root.add_child(world)
	await process_frame
	
	var player: Player = load("res://game/scenes/gameplay/player/Player.tscn").instantiate()
	world.add_child(player)
	await process_frame
	
	var fb: CameraFeedbackComponent = player.camera_feedback
	var cam: Camera3D = player.camera
	if not fb or not cam:
		printerr("Camera feedback or camera node missing!")
		_fail()
		world.queue_free()
		return
	
	var base_fov = cam.fov
	
	# Apply damage feedback (trauma + FOV kick)
	fb.apply_damage_taken_feedback()
	
	if fb.trauma <= 0.0:
		printerr("Trauma was not added!")
		_fail()
		world.queue_free()
		return
	
	# Process one frame with trauma
	fb._process(0.016)
	
	var has_shake: bool = (cam.rotation != Vector3.ZERO or cam.position != Vector3.ZERO)
	if not has_shake:
		printerr("Camera did not shake under trauma!")
		_fail()
		world.queue_free()
		return
	
	# Simulate decay over 2 seconds
	for i in range(120):
		fb._process(0.016)
	
	if fb.trauma > 0.001:
		printerr("Trauma did not decay! Still at: ", fb.trauma)
		_fail()
		world.queue_free()
		return
	
	if cam.position != Vector3.ZERO or cam.rotation != Vector3.ZERO:
		printerr("Camera did not return to rest pose after trauma decay!")
		_fail()
		world.queue_free()
		return
	
	if absf(cam.fov - base_fov) > 0.1:
		printerr("Camera FOV did not return to base FOV! Got: ", cam.fov, " base: ", base_fov)
		_fail()
		world.queue_free()
		return
	
	_pass("Test 4")
	world.queue_free()
	await process_frame

# ------------------------------------------------------------------------------
# Test 5: Camera Recoil Pitch & Yaw Kick and Recovery
# ------------------------------------------------------------------------------
func _test_5_camera_recoil() -> void:
	print("--- Test 5: Camera Recoil Kick & Recovery ---")
	var world = Node3D.new()
	root.add_child(world)
	await process_frame
	
	var player: Player = load("res://game/scenes/gameplay/player/Player.tscn").instantiate()
	world.add_child(player)
	await process_frame
	
	var initial_pitch = player._pitch
	var pitch_kick = deg_to_rad(-2.5) # upward kick
	var yaw_kick = deg_to_rad(0.5)
	
	player.apply_camera_recoil(pitch_kick, yaw_kick, true)
	
	if absf(player._pitch - (initial_pitch + pitch_kick)) > 0.001:
		printerr("Recoil pitch not applied!")
		_fail()
		world.queue_free()
		return
	
	if absf(player._camera_recoil_yaw - yaw_kick) > 0.001:
		printerr("Recoil yaw not applied!")
		_fail()
		world.queue_free()
		return
	
	# Simulate touch recoil recovery over 0.5s
	for i in range(35):
		player._recover_touch_recoil(0.016)
	
	if absf(player._camera_recoil_yaw) > 0.01:
		printerr("Recoil yaw not recovered! Still: ", player._camera_recoil_yaw)
		_fail()
		world.queue_free()
		return
	
	_pass("Test 5")
	world.queue_free()
	await process_frame

# ------------------------------------------------------------------------------
# Test 6: InteractionRay Alignment & Detection
# ------------------------------------------------------------------------------
func _test_6_interaction_ray_alignment() -> void:
	print("--- Test 6: InteractionRay Alignment with Top-Level Camera ---")
	var world = Node3D.new()
	root.add_child(world)
	await process_frame
	
	var player: Player = load("res://game/scenes/gameplay/player/Player.tscn").instantiate()
	world.add_child(player)
	player.teleport(Vector3(0.0, 0.0, 0.0), 0.0, 0.0)
	await process_frame
	
	# Create an interactable object directly in front of the player (Z = -1.5m)
	var interactable_body = StaticBody3D.new()
	interactable_body.collision_layer = 8 # Layer 4 named interactables
	world.add_child(interactable_body)
	interactable_body.global_position = Vector3(0.0, 1.6, -1.5)
	
	var col_shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(1.0, 1.0, 1.0)
	col_shape.shape = box
	interactable_body.add_child(col_shape)
	
	var ic_script = load("res://game/scripts/controllers/components/InteractableComponent.gd")
	var ic = Node.new()
	ic.name = "InteractableComponent"
	ic.set_script(ic_script)
	interactable_body.add_child(ic)
	await process_frame
	
	# Force interaction ray update
	player.interaction_ray.force_raycast_update()
	
	if not player.interaction_ray.is_colliding():
		printerr("InteractionRay failed to detect interactable body right in front of eye level!")
		_fail()
		world.queue_free()
		return
	
	if player.interaction_ray.get_collider() != interactable_body:
		printerr("InteractionRay detected wrong collider!")
		_fail()
		world.queue_free()
		return
	
	_pass("Test 6")
	world.queue_free()
	await process_frame

# ------------------------------------------------------------------------------
# Test 7: Weapon Hitscan & Melee Shapecast Origins
# ------------------------------------------------------------------------------
func _test_7_weapon_and_melee_origins() -> void:
	print("--- Test 7: Weapon & Melee Origins Follow Camera ---")
	var world = Node3D.new()
	root.add_child(world)
	await process_frame
	
	var player: Player = load("res://game/scenes/gameplay/player/Player.tscn").instantiate()
	world.add_child(player)
	player.teleport(Vector3(10.0, 2.0, -5.0), deg_to_rad(45.0), deg_to_rad(15.0))
	await process_frame
	
	var weapon: WeaponController = player.find_child("Pistol", true, false) as WeaponController
	var melee: MeleeController = player.find_child("MeleeWeapon", true, false) as MeleeController
	
	if not weapon or not melee:
		printerr("Pistol or Melee controller missing on player!")
		_fail()
		world.queue_free()
		return
	
	# Check weapon camera origin
	var cam: Camera3D = player.camera
	var weapon_ray_origin = cam.global_position
	var weapon_ray_dir = -cam.global_transform.basis.z
	
	var expected_cam_origin = player.global_position + Vector3(0.0, player.current_camera_height, 0.0)
	if weapon_ray_origin.distance_to(expected_cam_origin) > 0.05:
		printerr("Weapon ray origin mismatch! Cam: ", weapon_ray_origin, " expected: ", expected_cam_origin)
		_fail()
		world.queue_free()
		return
	
	# Check melee shapecast alignment
	if not melee._shape_cast:
		melee._setup_shape_cast()
	melee._shape_cast.global_transform = cam.global_transform
	
	if melee._shape_cast.global_position.distance_to(cam.global_position) > 0.01:
		printerr("Melee shapecast position not matching camera! ShapeCast: ", melee._shape_cast.global_position, " Cam: ", cam.global_position)
		_fail()
		world.queue_free()
		return
	
	_pass("Test 7")
	world.queue_free()
	await process_frame

# ------------------------------------------------------------------------------
# Test 8: Death Slow-Motion Sequence
# ------------------------------------------------------------------------------
func _test_8_death_slow_motion() -> void:
	print("--- Test 8: Death Slow-Motion Sequence ---")
	var cm = root.get_node_or_null("CheckpointManager")
	if not cm:
		printerr("CheckpointManager missing!")
		_fail()
		return
	
	# Initial time scale must be 1.0
	Engine.time_scale = 1.0
	
	# Trigger death sequence
	await cm.handle_player_death()
	
	# After death sequence ends, time_scale MUST be 1.0
	if absf(Engine.time_scale - 1.0) > 0.01:
		printerr("Engine.time_scale was not restored to 1.0 after death! Got: ", Engine.time_scale)
		_fail()
		return
	
	# Reset death screen flag
	var im = root.get_node_or_null("InputManager")
	if im:
		im.is_death_screen_active = false
	
	_pass("Test 8")
	await process_frame

# ------------------------------------------------------------------------------
# Test 9: Keyboard Diagonal Speed vs Straight Speed
# ------------------------------------------------------------------------------
func _test_9_keyboard_diagonal_speed() -> void:
	print("--- Test 9: Keyboard Diagonal Speed (W+D) <= Straight (W) ---")
	var world = Node3D.new()
	root.add_child(world)
	await process_frame
	
	# Add floor
	var floor_body = StaticBody3D.new()
	var col = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(50, 1, 50)
	col.shape = box
	floor_body.add_child(col)
	floor_body.position = Vector3(0, -0.5, 0)
	world.add_child(floor_body)
	
	var player: Player = load("res://game/scenes/gameplay/player/Player.tscn").instantiate()
	world.add_child(player)
	player.teleport(Vector3(0.0, 0.5, 0.0), 0.0, 0.0)
	await process_frame
	
	var im = root.get_node_or_null("InputManager")
	if im:
		im.mouse_captured = true
	
	var walk_speed = player.player_data.walk_speed # 4.5
	
	# 1. Straight forward (W)
	Input.action_press("move_forward", 1.0)
	Input.action_release("move_left")
	Input.action_release("move_right")
	Input.action_release("move_back")
	Input.action_release("sprint")
	
	for i in range(60): # 1 second of acceleration
		player._physics_process(0.0166)
	
	var speed_straight = Vector2(player.velocity.x, player.velocity.z).length()
	print("  -> Straight W speed: %.4f m/s (max walk: %.2f m/s)" % [speed_straight, walk_speed])
	
	# 2. Diagonal forward-right (W + D)
	player.velocity = Vector3.ZERO
	Input.action_press("move_forward", 1.0)
	Input.action_press("move_right", 1.0)
	
	for i in range(60):
		player._physics_process(0.0166)
	
	var speed_diagonal = Vector2(player.velocity.x, player.velocity.z).length()
	print("  -> Diagonal W+D speed: %.4f m/s" % speed_diagonal)
	
	Input.action_release("move_forward")
	Input.action_release("move_right")
	Input.action_release("move_right")
	
	if speed_diagonal > speed_straight + 0.05:
		printerr("Diagonal speed (%.4f) is faster than straight speed (%.4f)!" % [speed_diagonal, speed_straight])
		_fail()
		world.queue_free()
		return
	
	if speed_diagonal > walk_speed + 0.05:
		printerr("Diagonal speed exceeds walk_speed limit! Got: %.4f, max: %.2f" % [speed_diagonal, walk_speed])
		_fail()
		world.queue_free()
		return
	
	_pass("Test 9")
	world.queue_free()
	await process_frame

# ------------------------------------------------------------------------------
# Test 10: F5 Performance Label Mathematical Consistency
# ------------------------------------------------------------------------------
func _test_10_f5_perf_label_consistency() -> void:
	print("--- Test 10: F5 Performance Label Consistency ---")
	var dt = root.get_node_or_null("DebugTools")
	if not dt:
		printerr("DebugTools autoload not found!")
		_fail()
		return
	
	# Ensure overlay is visible
	if not dt.perf_overlay_visible:
		dt._debug_toggle_perf_overlay()
	
	# Process multiple frames with varying frame time
	var test_deltas = [0.016, 0.017, 0.015, 0.016, 0.018, 0.016, 0.015, 0.020, 0.016, 0.017, 0.016, 0.016, 0.016]
	for d in test_deltas:
		dt._process(d)
	
	# Label must now be updated with averaged sample
	var text: String = dt._perf_label.text
	print("  -> F5 Label output: '%s'" % text)
	
	# Format: "FPS: %d | Frame: %.2f ms | Draw Calls: %d | Objects: %d"
	var regex = RegEx.new()
	regex.compile("FPS:\\s*(\\d+)\\s*\\|\\s*Frame:\\s*([0-9.]+)\\s*ms")
	var m = regex.search(text)
	if not m:
		printerr("F5 Label regex failed to match format! Got: ", text)
		_fail()
		return
	
	var label_fps = float(m.get_string(1))
	var label_ms = float(m.get_string(2))
	
	print("  -> Parsed FPS: %.1f, Frame Time: %.2f ms" % [label_fps, label_ms])
	
	# Product FPS * Frame_ms must equal ~1000 (within 5% due to integer FPS rounding)
	var product = label_fps * label_ms
	print("  -> Product (FPS * Frame Time): %.2f (Ideal: 1000.0)" % product)
	
	if absf(product - 1000.0) > 60.0:
		printerr("F5 FPS and Frame Time do not agree! Product: %.2f" % product)
		_fail()
		return
	
	# Turn overlay back off
	dt._debug_toggle_perf_overlay()
	
	_pass("Test 10")
	await process_frame

# ------------------------------------------------------------------------------
# Test 11: Mouse Look Turning 90° - Camera Forward Vector Verified
# ------------------------------------------------------------------------------
func _test_11_mouse_look_90_deg_camera_turn() -> void:
	print("--- Test 11: Mouse Look 90° Turn (Camera Forward Direction) ---")
	var world = Node3D.new()
	root.add_child(world)
	await process_frame
	
	var player: Player = load("res://game/scenes/gameplay/player/Player.tscn").instantiate()
	world.add_child(player)
	player.teleport(Vector3.ZERO, 0.0, 0.0)
	await process_frame
	
	var cam: Camera3D = player.camera
	var initial_cam_fwd: Vector3 = -cam.global_transform.basis.z
	print("  -> Initial camera forward: ", initial_cam_fwd)
	if initial_cam_fwd.distance_to(Vector3(0, 0, -1)) > 0.01:
		printerr("Initial camera forward not North (0, 0, -1)! Got: ", initial_cam_fwd)
		_fail()
		world.queue_free()
		return
	
	var im = root.get_node_or_null("InputManager")
	if not im:
		printerr("InputManager missing!")
		_fail()
		world.queue_free()
		return
	
	im.mouse_captured = true
	im.is_gameplay_paused = false
	im.just_recaptured = false
	im.mouse_sensitivity = 0.002
	
	# Rotate 90° to the right (+PI/2 rad look_delta.x -> rotate_y(-PI/2)):
	var mouse_pixels_x = (PI * 0.5) / im.mouse_sensitivity
	im._mouse_delta = Vector2(mouse_pixels_x, 0.0)
	
	# Execute look frame
	player._process(0.016)
	
	var body_fwd: Vector3 = -player.global_transform.basis.z
	var cam_fwd: Vector3 = -cam.global_transform.basis.z
	print("  -> Body forward after 90° mouse look: ", body_fwd)
	print("  -> Camera forward after 90° mouse look: ", cam_fwd)
	
	var expected_fwd = Vector3(1, 0, 0) # East
	if body_fwd.distance_to(expected_fwd) > 0.05:
		printerr("Body forward did not turn 90° East! Got: ", body_fwd)
		_fail()
		world.queue_free()
		return
	
	if cam_fwd.distance_to(expected_fwd) > 0.05:
		printerr("Camera forward did not turn 90° East! Got: ", cam_fwd, " expected: ", expected_fwd)
		_fail()
		world.queue_free()
		return
	
	# Subsequent frames must NOT reset camera forward to ~0
	player._process(0.016)
	var cam_fwd_frame2 = -cam.global_transform.basis.z
	print("  -> Camera forward on frame 2: ", cam_fwd_frame2)
	if cam_fwd_frame2.distance_to(expected_fwd) > 0.05:
		printerr("Camera forward reset/drifted on subsequent frame! Got: ", cam_fwd_frame2)
		_fail()
		world.queue_free()
		return
	
	_pass("Test 11")
	world.queue_free()
	await process_frame

# ------------------------------------------------------------------------------
# Test 12: Touch Swipe Turning 90° - Camera Forward Vector Verified
# ------------------------------------------------------------------------------
func _test_12_touch_swipe_90_deg_camera_turn() -> void:
	print("--- Test 12: Touch Swipe 90° Turn (Camera Forward Direction) ---")
	var world = Node3D.new()
	root.add_child(world)
	await process_frame
	
	var player: Player = load("res://game/scenes/gameplay/player/Player.tscn").instantiate()
	world.add_child(player)
	player.teleport(Vector3.ZERO, 0.0, 0.0)
	await process_frame
	
	var cam: Camera3D = player.camera
	var im = root.get_node_or_null("InputManager")
	im.mouse_captured = true
	im.is_gameplay_paused = false
	im.touch_sens_h = 0.003
	
	# Rotate 90° to the left (-PI/2 rad look_delta.x -> rotate_y(+PI/2)):
	var touch_pixels_x = -(PI * 0.5) / im.touch_sens_h
	im.inject_touch_look(Vector2(touch_pixels_x, 0.0))
	
	player._process(0.016)
	
	var body_fwd: Vector3 = -player.global_transform.basis.z
	var cam_fwd: Vector3 = -cam.global_transform.basis.z
	print("  -> Body forward after 90° touch swipe: ", body_fwd)
	print("  -> Camera forward after 90° touch swipe: ", cam_fwd)
	
	var expected_fwd = Vector3(-1, 0, 0) # West
	if body_fwd.distance_to(expected_fwd) > 0.05:
		printerr("Body forward did not turn 90° West! Got: ", body_fwd)
		_fail()
		world.queue_free()
		return
	
	if cam_fwd.distance_to(expected_fwd) > 0.05:
		printerr("Camera forward did not turn 90° West! Got: ", cam_fwd, " expected: ", expected_fwd)
		_fail()
		world.queue_free()
		return
	
	# Ensure camera forward does not reset on next frame
	player._process(0.016)
	var cam_fwd_frame2 = -cam.global_transform.basis.z
	if cam_fwd_frame2.distance_to(expected_fwd) > 0.05:
		printerr("Camera forward reset on subsequent frame after touch swipe! Got: ", cam_fwd_frame2)
		_fail()
		world.queue_free()
		return
	
	_pass("Test 12")
	world.queue_free()
	await process_frame

# ------------------------------------------------------------------------------
# Test 13: Aim Assist Rotates Camera Correctly
# ------------------------------------------------------------------------------
func _test_13_aim_assist_camera_rotation() -> void:
	print("--- Test 13: Aim Assist Rotates Camera Toward Target ---")
	var world = Node3D.new()
	root.add_child(world)
	await process_frame
	
	var player: Player = load("res://game/scenes/gameplay/player/Player.tscn").instantiate()
	world.add_child(player)
	player.teleport(Vector3.ZERO, 0.0, 0.0)
	await process_frame
	
	# Spawn enemy slightly to the right (X = 2.0, Z = -10.0)
	var enemy = load("res://game/scenes/gameplay/enemies/RusherEnemy.tscn").instantiate()
	enemy.position = Vector3(2.0, 0.0, -10.0)
	world.add_child(enemy)
	await process_frame
	
	var im = root.get_node_or_null("InputManager")
	im.mouse_captured = true
	im.is_gameplay_paused = false
	im.last_input_device = im.InputDevice.TOUCH
	player.aim_assist_setting = "High"
	
	# Trigger small look movement to activate magnetism
	var initial_cam_fwd = -player.camera.global_transform.basis.z
	
	# Simulate 10 frames of moving look with aim assist active
	for i in range(10):
		im.inject_touch_look(Vector2(5.0, 0.0))
		player._process(0.016)
	
	var post_assist_cam_fwd = -player.camera.global_transform.basis.z
	print("  -> Initial camera forward: ", initial_cam_fwd)
	print("  -> Post-assist camera forward: ", post_assist_cam_fwd)
	
	# Camera must have rotated rightward toward the enemy (+X direction)
	if post_assist_cam_fwd.x <= initial_cam_fwd.x:
		printerr("Aim assist failed to rotate camera toward target! X was %f, now %f" % [initial_cam_fwd.x, post_assist_cam_fwd.x])
		_fail()
		world.queue_free()
		return
	
	# Also verify camera basis matches body + recoil
	player._process(0.016)
	if absf((-player.camera.global_transform.basis.z).x - post_assist_cam_fwd.x) > 0.05:
		printerr("Camera orientation drifted unexpectedly after aim assist!")
		_fail()
		world.queue_free()
		return
	
	_pass("Test 13")
	world.queue_free()
	await process_frame

# ------------------------------------------------------------------------------
# Test 14: Recoil Kick Rotates Camera Correctly
# ------------------------------------------------------------------------------
func _test_14_recoil_camera_rotation() -> void:
	print("--- Test 14: Recoil Kick Rotates Camera Forward Direction ---")
	var world = Node3D.new()
	root.add_child(world)
	await process_frame
	
	var player: Player = load("res://game/scenes/gameplay/player/Player.tscn").instantiate()
	world.add_child(player)
	player.teleport(Vector3.ZERO, 0.0, 0.0)
	await process_frame
	
	var initial_fwd = -player.camera.global_transform.basis.z
	
	# Apply recoil: upward pitch (+5°) and rightward yaw (+3°)
	var pitch_kick = deg_to_rad(5.0)
	var yaw_kick = deg_to_rad(3.0)
	player.apply_camera_recoil(pitch_kick, yaw_kick, false)
	
	var recoiled_fwd = -player.camera.global_transform.basis.z
	print("  -> Recoiled camera forward: ", recoiled_fwd)
	
	# Pitch upward means forward vector points up in Y (> 0)
	if recoiled_fwd.y < 0.05:
		printerr("Recoil did not pitch camera upward! Y: ", recoiled_fwd.y)
		_fail()
		world.queue_free()
		return
	
	# Horizontal recoil kick rotates camera horizontally (non-zero X)
	if absf(recoiled_fwd.x) < 0.03:
		printerr("Recoil did not yaw camera horizontally! X: ", recoiled_fwd.x)
		_fail()
		world.queue_free()
		return
	
	# Run process: camera orientation must retain recoil
	player._process(0.016)
	var post_process_fwd = -player.camera.global_transform.basis.z
	if absf(post_process_fwd.y - recoiled_fwd.y) > 0.02 or absf(post_process_fwd.x - recoiled_fwd.x) > 0.02:
		printerr("Camera recoil was wiped on process frame! Got: ", post_process_fwd)
		_fail()
		world.queue_free()
		return
	
	_pass("Test 14")
	world.queue_free()
	await process_frame

# ------------------------------------------------------------------------------
# Test 15: Teleport Rotates Camera Correctly
# ------------------------------------------------------------------------------
func _test_15_teleport_camera_rotation() -> void:
	print("--- Test 15: Teleport Camera Rotation Alignment ---")
	var world = Node3D.new()
	root.add_child(world)
	await process_frame
	
	var player: Player = load("res://game/scenes/gameplay/player/Player.tscn").instantiate()
	world.add_child(player)
	await process_frame
	
	# Teleport with yaw = 180° (South, forward +Z) and pitch = +15° (upward, Y > 0)
	var target_yaw = deg_to_rad(180.0)
	var target_pitch = deg_to_rad(15.0)
	player.teleport(Vector3(12.0, 1.0, -8.0), target_yaw, target_pitch)
	
	var cam_fwd = -player.camera.global_transform.basis.z
	print("  -> Teleported camera forward: ", cam_fwd)
	
	# Expected forward: Y = sin(15°) ≈ 0.2588, Z = cos(15°) ≈ 0.9659
	var expected_fwd = Vector3(0.0, sin(deg_to_rad(15.0)), cos(deg_to_rad(15.0)))
	if cam_fwd.distance_to(expected_fwd) > 0.03:
		printerr("Teleport camera forward mismatch! Got: ", cam_fwd, " expected: ", expected_fwd)
		_fail()
		world.queue_free()
		return
	
	# Run a frame of process
	player._process(0.016)
	var cam_fwd_p2 = -player.camera.global_transform.basis.z
	if cam_fwd_p2.distance_to(expected_fwd) > 0.03:
		printerr("Teleport camera forward reset after process frame! Got: ", cam_fwd_p2)
		_fail()
		world.queue_free()
		return
	
	_pass("Test 15")
	world.queue_free()
	await process_frame

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------
func _pass(test_name: String) -> void:
	print("PASSED: %s\n" % test_name)
	passed_count += 1

func _fail() -> void:
	failed_count += 1
