extends SceneTree

## Project: Lockdown - Combat Feedback Test Suite
## 1. Player bullets pass the player as source: a shot enemy chases the shooter
## 2. damage_dealt fires on hits (killed=false) and kills (killed=true), never on walls
## 3. Crosshair hit marker: white on hit, red and longer on kill, then fades
## 4. Damage direction indicator: correct screen angles, one arc per attacker, fades after 1s
## 5. Enemy death fall: body tips over, and checkpoint rollback stands it back up
## 6. Objective text: Floor 1 shows exit + optional rescue; rescue removes the optional line
## 7. Haptics setting: saved toggle, vibrate() safe with it on or off

var passed_count: int = 0
var failed_count: int = 0

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	print("\n=== STARTING COMBAT FEEDBACK TEST SUITE ===\n")
	await _run("Test 1: Bullets alert the enemy to the shooter", _test_bullet_source)
	await _run("Test 2: damage_dealt on hit and kill, not on walls", _test_damage_dealt)
	await _run("Test 3: Crosshair hit marker", _test_hit_marker)
	await _run("Test 4: Damage direction indicator", _test_damage_indicator)
	await _run("Test 5: Enemy death fall and rollback", _test_death_fall)
	await _run("Test 6: Objective text on Floor 1", _test_objective)
	await _run("Test 7: Haptics setting", _test_haptics)

	print("\n=======================================================")
	print("RESULTS: %d Passed, %d Failed" % [passed_count, failed_count])
	print("=======================================================\n")
	if failed_count == 0:
		print("ALL COMBAT FEEDBACK TESTS PASSED!\n")
	quit(0 if failed_count == 0 else 1)

func _run(title: String, test: Callable) -> void:
	print("--- %s ---" % title)
	var ok: bool = await test.call()
	if ok:
		passed_count += 1
		print("PASSED")
	else:
		failed_count += 1
		print("FAILED: %s" % title)

func _fail(msg: String) -> bool:
	printerr("  " + msg)
	return false

## Empty world with a floor, the player at the origin facing -Z, and one ranged enemy 5m ahead.
func _make_arena() -> Dictionary:
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	floor_shape.shape = box
	floor_shape.position = Vector3(0, -0.5, 0)
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)
	var player: Node3D = load("res://scenes/player/player.tscn").instantiate()
	world.add_child(player)
	var enemy: EnemyBase = load("res://scenes/enemies/ranged_enemy.tscn").instantiate()
	world.add_child(enemy)
	enemy.global_position = Vector3(0, 0, -5)
	enemy.rotation.y = 0.0 # facing away from the player (-Z), so it can't see the shooter
	for i in 4:
		await physics_frame
	player.teleport(Vector3.ZERO, 0.0, 0.0)
	enemy.change_state(EnemyBase.State.PATROL)
	await physics_frame
	return { "world": world, "player": player, "enemy": enemy }

func _test_bullet_source() -> bool:
	var a: Dictionary = await _make_arena()
	var enemy: EnemyBase = a.enemy
	var pistol: WeaponController = a.player.find_child("Pistol", true, false)
	var hp_before: float = enemy.health_component.current_health
	pistol._perform_hitscan()
	var ok := true
	if enemy.health_component.current_health >= hp_before:
		ok = _fail("Enemy took no damage from the shot")
	elif enemy.current_state != EnemyBase.State.CHASE:
		ok = _fail("Shot enemy did not chase the shooter (state %s)" % enemy.get_state_name())
	elif enemy.last_known_player_position.distance_to(a.player.global_position) > 0.5:
		ok = _fail("Enemy's last known position is not the shooter's position")
	a.world.queue_free()
	await process_frame
	return ok

func _test_damage_dealt() -> bool:
	var a: Dictionary = await _make_arena()
	var enemy: EnemyBase = a.enemy
	var pistol: WeaponController = a.player.find_child("Pistol", true, false)
	var events: Array = []
	pistol.damage_dealt.connect(func(t, killed): events.append([t, killed]))
	pistol._perform_hitscan()
	enemy.health_component.current_health = 1.0
	pistol._perform_hitscan()
	# Third shot at a wall: turn around to face +Z where only the floor edge/nothing is; add a wall there
	var wall := StaticBody3D.new()
	var ws := CollisionShape3D.new()
	var wb := BoxShape3D.new()
	wb.size = Vector3(4, 4, 0.5)
	ws.shape = wb
	wall.add_child(ws)
	a.world.add_child(wall)
	wall.global_position = Vector3(0, 1.5, 3)
	a.player.teleport(Vector3.ZERO, PI, 0.0)
	await physics_frame
	pistol._perform_hitscan()
	var ok := true
	if events.size() != 2:
		ok = _fail("Expected 2 damage_dealt events (hit + kill, none for the wall), got %d" % events.size())
	elif events[0][0] != enemy or events[0][1] != false:
		ok = _fail("First hit should be on the enemy with killed=false")
	elif events[1][1] != true:
		ok = _fail("Killing shot should report killed=true")
	a.world.queue_free()
	await process_frame
	return ok

func _test_hit_marker() -> bool:
	var ch := DynamicCrosshair.new()
	root.add_child(ch)
	await process_frame
	ch.show_hit_marker(null, false)
	var ok := true
	if ch._hit_timer <= 0.0 or ch._hit_was_kill:
		ok = _fail("Hit marker not shown as a normal hit")
	var hit_time: float = ch._hit_timer
	ch.show_hit_marker(null, true)
	if ok and (not ch._hit_was_kill or ch._hit_timer <= hit_time):
		ok = _fail("Kill marker should be red and last longer than a hit")
	ch._process(1.0)
	if ok and ch._hit_timer > 0.0:
		ok = _fail("Hit marker did not fade out")
	ch.queue_free()
	return ok

func _test_damage_indicator() -> bool:
	var a: Dictionary = await _make_arena()
	var cam: Camera3D = a.player.find_child("Camera3D", true, false)
	var eye: Vector3 = cam.global_position
	var ok := true
	var cases := {
		"front": [eye + Vector3(0, 0, -5), 0.0],
		"right": [eye + Vector3(5, 0, 0), PI * 0.5],
		"left": [eye + Vector3(-5, 0, 0), -PI * 0.5],
	}
	for k in cases:
		var got: float = DamageDirectionIndicator.screen_angle_to(cam, cases[k][0])
		if absf(angle_difference(got, cases[k][1])) > 0.05:
			ok = _fail("Attacker %s: angle %.2f, expected %.2f" % [k, got, cases[k][1]])
	var behind: float = DamageDirectionIndicator.screen_angle_to(cam, eye + Vector3(0, 0, 5))
	if absf(absf(behind) - PI) > 0.05:
		ok = _fail("Attacker behind should be at ±PI, got %.2f" % behind)

	var ind := DamageDirectionIndicator.new()
	root.add_child(ind)
	ind.add_hit(a.enemy)
	ind.add_hit(a.enemy)
	ind.add_hit(null) # e.g. debug damage with no source
	if ind._hits.size() != 1:
		ok = _fail("Expected one arc for one attacker, got %d" % ind._hits.size())
	ind._process(1.1)
	if ind._hits.size() != 0:
		ok = _fail("Arc did not fade out after its duration")
	ind.queue_free()
	a.world.queue_free()
	await process_frame
	return ok

func _test_death_fall() -> bool:
	var a: Dictionary = await _make_arena()
	var enemy: EnemyBase = a.enemy
	var spawn: Transform3D = enemy.global_transform
	enemy.take_damage(1000.0, a.player, "bullet")
	for i in 40:
		await physics_frame
	var ok := true
	if enemy.current_state != EnemyBase.State.DEAD:
		ok = _fail("Enemy not dead")
	elif absf(enemy.rotation.x - PI * 0.5) > 0.05:
		ok = _fail("Dead enemy did not fall over (rotation.x %.2f)" % enemy.rotation.x)
	enemy.reset_to_spawn(spawn)
	for i in 5:
		await physics_frame
	if ok and (absf(enemy.rotation.x) > 0.01 or enemy.current_state == EnemyBase.State.DEAD):
		ok = _fail("Rollback did not stand the enemy back up (rotation.x %.2f)" % enemy.rotation.x)
	a.world.queue_free()
	await process_frame
	return ok

func _test_objective() -> bool:
	change_scene_to_file("res://scenes/levels/floor_01.tscn")
	for i in 10:
		await process_frame
	var od: ObjectiveDisplay = current_scene.find_child("ObjectiveDisplay", true, false)
	if od == null:
		return _fail("No ObjectiveDisplay in the Floor 1 HUD")
	var ok := true
	if not ("Stair B" in od.text and "Optional" in od.text):
		ok = _fail("Floor 1 objective should name the exit and the optional rescue, got: '%s'" % od.text)
	var captive = get_first_node_in_group("captives")
	var player = get_first_node_in_group("player")
	captive.complete_interaction(player)
	for i in 3:
		await process_frame
	if ok and "Optional" in od.text:
		ok = _fail("Optional rescue line still shown after the rescue")
	if ok and od._show_timer <= 0.0:
		ok = _fail("Objective change was not shown to the player")
	return ok

func _test_haptics() -> bool:
	var sm = root.get_node("SettingsManager")
	var old: bool = sm.haptics
	sm.set_setting("haptics", false, false)
	sm.vibrate(20, 0.5)
	var ok: bool = sm.haptics == false
	sm.set_setting("haptics", true, false)
	sm.vibrate(20, 0.5)
	if not sm.haptics:
		ok = false
	sm.haptics = old
	if not ok:
		return _fail("Haptics setting did not toggle")
	return true
