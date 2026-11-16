extends SceneTree

## Project: Lockdown - Ground Floor level checks
## 1. Built from kit instances only (no geometry defined inside the level file), 48 x 32m footprint
## 2. Content: 10 enemies, 3 checkpoints (one start), injured officer, exit to Floor 1
## 3. Baked navmesh reaches the exit landing, every enemy, the officer and every pickup from the street
## 4. Both routes to Stair A exist: main corridor, and service corridor + boiler room
## 5. Objective text names Stair A; reaching the exit loads Floor 1, which still ends in a clear screen
## 6. Home starts the Ground Floor
## 7. The player body can actually walk from the street up Stair A to the exit (doors, ramp)
## 8. ...and the same through the service corridor and the dark boiler room

const LEVEL := "res://game/scenes/gameplay/levels/GroundFloor.tscn"
const FLOOR1 := "res://game/scenes/gameplay/levels/Floor01.tscn"

var passed_count: int = 0
var failed_count: int = 0

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	await TestServices.start(self)
	print("\n=== STARTING GROUND FLOOR TEST SUITE ===\n")
	await _run("Test 1: Level is made of kit instances", _test_kit_only)
	change_scene_to_file(LEVEL)
	for i in 30:
		await physics_frame
	await _run("Test 2: Enemies, checkpoints, officer, exit", _test_content)
	await _run("Test 3: Navmesh reaches every objective", _test_navmesh_reach)
	await _run("Test 4: Two routes to Stair A", _test_two_routes)
	await _run("Test 5: Objective and exit to Floor 1", _test_exit)
	await _run("Test 6: Home starts the Ground Floor", _test_home)
	await _run("Test 7: Walk from the street to the exit", _test_walk_to_exit)
	await _run("Test 8: Walk via the boiler room", _test_walk_via_boiler)
	print("\nRESULTS: %d Passed, %d Failed\n" % [passed_count, failed_count])
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

func _test_kit_only() -> bool:
	var text := FileAccess.get_file_as_string(LEVEL)
	if text.contains("[sub_resource"):
		return _fail("GroundFloor.tscn defines its own resources; geometry should come from kit scenes")
	var level: Node3D = load(LEVEL).instantiate()
	var ok := true
	# Every MeshInstance3D/CollisionShape3D in Geometry must belong to an instanced kit scene
	for n in level.get_node("Geometry").find_children("*", "", true, false):
		if (n is MeshInstance3D or n is CollisionShape3D) and n.owner == level:
			ok = _fail("%s is drawn in the level itself, not a kit piece" % level.get_path_to(n))
			break
	var floor_tiles := level.get_node("Geometry/Shell/Floor").get_children().filter(func(t): return t.name.begins_with("Floor_"))
	var lo := Vector3(INF, 0, INF)
	var hi := Vector3(-INF, 0, -INF)
	for t in floor_tiles:
		lo = Vector3(minf(lo.x, t.position.x - 4), 0, minf(lo.z, t.position.z - 4))
		hi = Vector3(maxf(hi.x, t.position.x + 4), 0, maxf(hi.z, t.position.z + 4))
	if (hi - lo) != Vector3(48, 0, 32):
		ok = _fail("Building footprint is %v, expected 48 x 32" % (hi - lo))
	level.free()
	return ok

func _test_content() -> bool:
	var ok := true
	var enemies := get_nodes_in_group("enemies")
	if enemies.size() != 10:
		ok = _fail("Expected 10 enemies, found %d" % enemies.size())
	var cps := current_scene.find_children("*", "Area3D", true, false).filter(func(n): return n is Checkpoint)
	if cps.size() != 3 or cps.filter(func(c): return c.is_start_checkpoint).size() != 1:
		ok = _fail("Expected 3 checkpoints with one start checkpoint, found %d" % cps.size())
	var captives := get_nodes_in_group("captives")
	if captives.size() != 1 or captives[0].officer_name != "Officer Reyes":
		ok = _fail("Expected the injured officer (Officer Reyes)")
	var exits := current_scene.find_children("*", "LevelExitTrigger", true, false)
	if exits.size() != 1 or exits[0].next_level != FLOOR1:
		ok = _fail("Expected one exit leading to Floor 1")
	return ok

func _path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var map: RID = current_scene.get_world_3d().navigation_map
	return NavigationServer3D.map_get_path(map, from, to, true)

## Path ends within reach of the target (the navmesh is eroded by the agent radius around props).
func _reaches(from: Vector3, to: Vector3, tolerance: float = 1.2) -> bool:
	var p := _path(from, to)
	return p.size() > 1 and p[p.size() - 1].distance_to(to) <= tolerance

func _test_navmesh_reach() -> bool:
	var start: Vector3 = get_first_node_in_group("player").global_position
	var ok := true
	var exit: Node3D = current_scene.find_children("*", "LevelExitTrigger", true, false)[0]
	if not _reaches(start, exit.global_position, 1.5):
		ok = _fail("No walkable path from the street to the Stair A landing")
	for e in get_nodes_in_group("enemies"):
		if not _reaches(e.global_position, start):
			ok = _fail("Enemy %s cannot path to the street" % e.name)
	if not _reaches(start, get_nodes_in_group("captives")[0].global_position, 1.6):
		ok = _fail("No path to the injured officer")
	for pk in current_scene.get_node("Pickups").get_children():
		var target: Vector3 = pk.global_position
		target.y = 0.0
		if not _reaches(start, target, 1.6):
			ok = _fail("No path to pickup %s" % pk.name)
	return ok

func _test_two_routes() -> bool:
	# Close the main corridor's east end by asking for a path that must go through the boiler room
	var ok := true
	var stair_base := Vector3(45, 0, 11)
	if not _reaches(Vector3(40, 0, 11), stair_base):
		ok = _fail("Main corridor does not reach Stair A")
	if not _reaches(Vector3(37, 0, 30), Vector3(43, 0, 26)):
		ok = _fail("Service corridor does not open into the boiler room")
	if not _reaches(Vector3(45, 0, 14), stair_base):
		ok = _fail("Boiler room does not open into Stair A")
	return ok

func _test_exit() -> bool:
	var od: ObjectiveDisplay = current_scene.find_child("ObjectiveDisplay", true, false)
	if od == null or not od.build_text().contains("Stair A"):
		return _fail("Objective should point at Stair A, got '%s'" % (od.build_text() if od else "no display"))
	var exit: LevelExitTrigger = current_scene.find_children("*", "LevelExitTrigger", true, false)[0]
	exit._on_body_entered(get_first_node_in_group("player"))
	for i in 60:
		await process_frame
	if current_scene.scene_file_path != FLOOR1:
		return _fail("Exit did not load Floor 1 (at %s)" % current_scene.scene_file_path)
	var f1_exit: LevelExitTrigger = current_scene.find_children("*", "LevelExitTrigger", true, false)[0]
	if f1_exit.next_level != "":
		return _fail("Floor 1 should be the last level (level clear screen)")
	var ui: UIManager = TestServices.get_service(self, &"ui")
	if ui.stack_size() != 0 or paused:
		return _fail("Floor 1 started with a panel open or paused")
	return true

func _test_home() -> bool:
	var src := FileAccess.get_file_as_string("res://game/scenes/Home/Home.gd")
	if not src.contains('FIRST_LEVEL: String = "%s"' % LEVEL):
		return _fail("Home does not start the Ground Floor")
	return true

## Steers the real Player (move_forward + yaw) along the navmesh path, enemies switched off.
func _test_walk_to_exit() -> bool:
	return await _walk([])

func _test_walk_via_boiler() -> bool:
	return await _walk([Vector3(37, 0, 30), Vector3(43, 0, 26)])

func _walk(via: Array) -> bool:
	change_scene_to_file(LEVEL)
	for i in 30:
		await physics_frame
	for e in get_nodes_in_group("enemies"):
		e.process_mode = Node.PROCESS_MODE_DISABLED
	var player: Player = get_first_node_in_group("player")
	player.health_component.invulnerable = true
	var exit: LevelExitTrigger = current_scene.find_children("*", "LevelExitTrigger", true, false)[0]
	var stops: Array = [player.global_position] + via + [exit.global_position]
	var path := PackedVector3Array([stops[0]])
	for s in range(1, stops.size()):
		var leg := _path(stops[s - 1], stops[s])
		if leg.size() > 1:
			path.append_array(leg.slice(1))
	if path.size() < 2:
		return _fail("No navmesh path to walk")
	var i := 1
	var last_progress_pos := player.global_position
	var stuck_frames := 0
	Input.action_press("move_forward")
	for frame in 60 * 60:
		if current_scene == null or current_scene.scene_file_path == FLOOR1:
			break
		var flat := Vector2(player.global_position.x, player.global_position.z)
		var target := Vector2(path[i].x, path[i].z)
		if flat.distance_to(target) < 0.35 and i < path.size() - 1:
			i += 1
			target = Vector2(path[i].x, path[i].z)
		var d := target - flat
		player.rotation.y = atan2(-d.x, -d.y) # forward is -Z
		await physics_frame
		if frame % 60 == 0:
			if player.global_position.distance_to(last_progress_pos) < 0.3:
				stuck_frames += 60
			else:
				stuck_frames = 0
			last_progress_pos = player.global_position
			if stuck_frames >= 180:
				Input.action_release("move_forward")
				return _fail("Player got stuck at %v heading for waypoint %d %v" % [player.global_position, i, path[i]])
	Input.action_release("move_forward")
	for f in 60:
		await process_frame
	if current_scene.scene_file_path != FLOOR1:
		return _fail("Walk ended without reaching the exit")
	return true
