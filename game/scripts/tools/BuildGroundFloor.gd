extends SceneTree

## Generates game/scenes/gameplay/levels/GroundFloor.tscn and bakes its navmesh to
## game/assets/data/navmesh/ground_floor_navmesh.tres.
## Every wall, floor, ceiling, light and prop is an instance of a kit scene (modular/ or props/)
## placed on a 2m grid, so the saved level is edited in the editor like any hand-built scene.
## Re-running this overwrites hand edits to GroundFloor.tscn; after the first build, edit the scene.
##
## Run: godot --headless --script res://game/scripts/tools/BuildGroundFloor.gd
##
## Layout (X east 0..48, Z south 0..32; north = -Z; street outside the south wall):
##   Z 0-10  Storeroom(X0-10, to Z12) | Laundry 10-18 | G1 18-26 | G2 26-34 | Security 34-44 | Stair A 44-48 (to Z12)
##   Z10-12  Main corridor X10-44
##   Z12-32  Grocery X0-16 | Lobby X16-36 | Service corridor X36-38 | Boiler room X38-48
##   Z32-40  Street, entrance doors at X24-28

const OUT_SCENE := "res://game/scenes/gameplay/levels/GroundFloor.tscn"
const OUT_NAVMESH := "res://game/assets/data/navmesh/ground_floor_navmesh.tres"
const KIT := "res://game/scenes/gameplay/modular/"
const PROPS := "res://game/scenes/gameplay/props/"

var level: Node3D
var _scenes: Dictionary = {}

func _initialize() -> void:
	call_deferred("_build")

func _kit(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]

func _own(n: Node) -> void:
	n.owner = level

func _group(parent: Node, name: String) -> Node3D:
	var g := Node3D.new()
	g.name = name
	parent.add_child(g)
	_own(g)
	return g

func place(parent: Node, scene_path: String, name: String, pos: Vector3, rot_y_deg: float = 0.0) -> Node3D:
	var n: Node3D = _kit(scene_path).instantiate()
	n.name = name
	n.position = pos
	n.rotation.y = deg_to_rad(rot_y_deg)
	parent.add_child(n, true)
	_own(n)
	return n

## A straight wall along X (axis "x", at z = line) or along Z (axis "z", at x = line), from a to b in
## 2m cells. cells: optional {cell_index: "door" | "open" | "window" | "plaster"}; default is concrete.
func wall_run(parent: Node, prefix: String, axis: String, line: float, a: float, b: float, cells: Dictionary = {}, default_kind: String = "wall", y: float = 0.0) -> void:
	var count := int(round((b - a) / 2.0))
	for i in count:
		var kind: String = cells.get(i, default_kind)
		var path := ""
		match kind:
			"wall": path = KIT + "WallSegment.tscn"
			"plaster": path = KIT + "WallSegmentPlaster.tscn"
			"door": path = KIT + "DoorFrame.tscn"
			"window": path = KIT + "ShopWindow.tscn"
			"open": continue
		var c := a + 1.0 + 2.0 * i
		var pos := Vector3(c, y, line) if axis == "x" else Vector3(line, y, c)
		place(parent, path, "%s_%d" % [prefix, i], pos, 0.0 if axis == "x" else 90.0)

func _build() -> void:
	level = Node3D.new()
	level.name = "GroundFloor"
	root.add_child(level) # in the tree only while the static geometry is parsed for the navmesh

	var env := WorldEnvironment.new()
	env.name = "WorldEnvironment"
	env.environment = load("res://game/assets/environments/default_env.tres")
	level.add_child(env); _own(env)

	var sun := DirectionalLight3D.new()
	sun.name = "DirectionalLight3D"
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 0.25 # streetlight/moon spill; the interior is lit by ceiling lamps
	level.add_child(sun); _own(sun)

	var nav := NavigationRegion3D.new()
	nav.name = "NavigationRegion3D"
	level.add_child(nav); _own(nav)

	var geo := _group(level, "Geometry")
	_build_shell(_group(geo, "Shell"))
	_build_rooms(geo)

	# ── Navmesh, baked now and saved as its own resource ──
	var nm := NavigationMesh.new()
	nm.agent_height = 1.75
	nm.agent_radius = 0.4
	nm.agent_max_climb = 0.25 # a CharacterBody capsule does not step up ledges, so keep this low
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	# Up to 2.6m only: walkable floors and the stair landing, never the tops of the ceiling slabs
	nm.filter_baking_aabb = AABB(Vector3(-1, -1, -1), Vector3(50, 3.6, 42))
	var src := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nm, src, level)
	NavigationServer3D.bake_from_source_geometry_data(nm, src)
	print("Navmesh: %d vertices, %d polygons" % [nm.get_vertices().size(), nm.get_polygon_count()])
	print("Navmesh save: ", ResourceSaver.save(nm, OUT_NAVMESH))
	nav.navigation_mesh = load(OUT_NAVMESH)

	# Scripted nodes are added out of the tree so none of their _ready() code runs (and gets saved)
	root.remove_child(level)
	_build_lighting(_group(level, "Lighting"))
	_build_gameplay()
	level.set_script(load("res://game/scripts/controllers/level/LevelRoot.gd"))

	var packed := PackedScene.new()
	print("Pack: ", packed.pack(level))
	print("Scene save: ", ResourceSaver.save(packed, OUT_SCENE))
	quit()

# ── Floors, ceilings, outer walls ───────────────────────────────────────────
func _build_shell(shell: Node3D) -> void:
	var floors := _group(shell, "Floor")
	for ix in 6:
		for iz in 4:
			place(floors, KIT + "FloorTile8.tscn", "Floor_%d_%d" % [ix, iz], Vector3(4 + 8 * ix, 0, 4 + 8 * iz))
	for ix in 3: # street (no ceiling)
		place(floors, KIT + "FloorTile8.tscn", "Street_%d" % ix, Vector3(20 + 8 * ix, 0, 36))

	var ceil := _group(shell, "Ceiling")
	for ix in 5:
		for iz in 4:
			place(ceil, KIT + "CeilingTile8.tscn", "Ceiling_%d_%d" % [ix, iz], Vector3(4 + 8 * ix, 0, 4 + 8 * iz))
	for ix in 2: # X40-48 strip in 4m tiles so Stair A (X44-48, Z0-12) can have a double-height ceiling
		for iz in 8:
			var stair := ix == 1 and iz < 3
			place(ceil, KIT + "CeilingTile4.tscn", "Ceiling4_%d_%d" % [ix, iz], Vector3(42 + 4 * ix, 2.5 if stair else 0.0, 2 + 4 * iz))

	var outer := _group(shell, "OuterWalls")
	wall_run(outer, "North", "x", 0, 0, 48)
	wall_run(outer, "West", "z", 0, 0, 32)
	wall_run(outer, "East", "z", 48, 0, 32)
	# South facade: grocery storefront windows, lobby windows either side of the broken entrance doors
	wall_run(outer, "South", "x", 32, 0, 48, {1: "window", 2: "window", 3: "window", 4: "window", 5: "window", 6: "window",
		9: "window", 10: "window", 12: "open", 13: "open", 15: "window", 16: "window"})
	# Stair A goes double height: a second row of wall pieces on its outer walls
	wall_run(outer, "StairNorthUpper", "x", 0, 44, 48, {}, "wall", 2.5)
	wall_run(outer, "StairEastUpper", "z", 48, 0, 12, {}, "wall", 2.5)
	wall_run(outer, "StairWestUpper", "z", 44, 0, 12, {}, "wall", 2.5)
	wall_run(outer, "StairSouthUpper", "x", 12, 44, 48, {}, "wall", 2.5)
	# Street: closed off by rubble walls so the player can only go in
	wall_run(outer, "StreetWest", "z", 16, 32, 40)
	wall_run(outer, "StreetEast", "z", 40, 32, 40)
	wall_run(outer, "StreetSouth", "x", 40, 16, 40)

# ── Interior walls and furniture, one group per room ────────────────────────
func _build_rooms(geo: Node3D) -> void:
	var r: Node3D

	r = _group(geo, "Room_Street")
	place(r, PROPS + "WreckedCar.tscn", "WreckedCar", Vector3(20.5, 0, 36), 12)
	place(r, KIT + "CoverBox.tscn", "Crate_A", Vector3(31, 0, 35.5))
	place(r, KIT + "CoverBox.tscn", "Crate_B", Vector3(32.1, 0, 35.6), 20)
	place(r, PROPS + "RubblePile.tscn", "Rubble", Vector3(35, 0, 38))

	r = _group(geo, "Room_Lobby")
	place(r, PROPS + "ReceptionDesk.tscn", "ReceptionDesk", Vector3(26, 0, 17))
	for p in [Vector3(21, 0, 19), Vector3(31, 0, 19), Vector3(21, 0, 25), Vector3(31, 0, 25)]:
		place(r, KIT + "Pillar.tscn", "Pillar", p)
	place(r, PROPS + "MailboxWall.tscn", "MailboxWall", Vector3(16.4, 0, 23), 90)
	place(r, PROPS + "MailboxWall.tscn", "MailboxWall2", Vector3(16.4, 0, 25), 90)
	place(r, PROPS + "Sofa.tscn", "Sofa", Vector3(35.2, 0, 21), -90)
	place(r, PROPS + "RubblePile.tscn", "Rubble", Vector3(24, 0, 27))
	place(r, PROPS + "RubblePile.tscn", "Rubble2", Vector3(29, 0, 22), 70)
	place(r, KIT + "BarricadeJunk.tscn", "Junk", Vector3(19, 0, 29), 30)
	place(r, KIT + "CoverBox.tscn", "Crate", Vector3(33, 0, 28))

	r = _group(geo, "Room_Grocery")
	wall_run(r, "Wall_Lobby", "z", 16, 12, 32, {3: "door", 6: "open"})
	for row in [16.0, 20.0, 24.0]:
		for x in [3.0, 5.0, 9.0, 11.0]:
			place(r, PROPS + "GroceryShelf.tscn", "Shelf", Vector3(x, 0, row))
	place(r, PROPS + "CheckoutCounter.tscn", "Checkout", Vector3(5, 0, 28.5))
	place(r, PROPS + "CheckoutCounter.tscn", "Checkout2", Vector3(10, 0, 28.5))
	place(r, KIT + "CoverBox.tscn", "Crate", Vector3(14, 0, 14))
	place(r, KIT + "CoverBox.tscn", "Crate2", Vector3(14.2, 0, 15.1), 15)

	r = _group(geo, "Room_Storeroom")
	wall_run(r, "Wall_Grocery", "x", 12, 0, 10, {2: "door"})
	wall_run(r, "Wall_East", "z", 10, 0, 12, {5: "door"}) # Z10-12 opens onto the corridor's west end
	for p in [Vector3(2, 0, 3), Vector3(3.1, 0, 3), Vector3(2.5, 1, 3)]:
		place(r, KIT + "CoverBox.tscn", "Crate", p)
	place(r, PROPS + "GroceryShelf.tscn", "Shelf", Vector3(8.6, 0, 4), 90)
	place(r, PROPS + "GroceryShelf.tscn", "Shelf2", Vector3(8.6, 0, 6), 90)
	place(r, PROPS + "Locker.tscn", "Locker", Vector3(0.5, 0, 8), 90)

	r = _group(geo, "Room_Corridor")
	# North side: doors into the laundry, G1, G2 and the security office
	wall_run(r, "Wall_North", "x", 10, 10, 44, {2: "door", 5: "door", 10: "door", 13: "door"}, "plaster")
	# South side: grocery door, two openings into the lobby, the service corridor
	wall_run(r, "Wall_South", "x", 12, 10, 44, {1: "door", 5: "open", 10: "open", 13: "open"})
	place(r, KIT + "BarricadeJunk.tscn", "Junk", Vector3(25, 0, 10.6), 90)

	r = _group(geo, "Room_Laundry")
	wall_run(r, "Wall_East", "z", 18, 0, 10, {}, "plaster")
	for i in 5:
		place(r, PROPS + "WashingMachine.tscn", "Washer", Vector3(11.2 + 0.75 * i, 0, 0.6))
	place(r, PROPS + "Table.tscn", "FoldingTable", Vector3(16, 0, 6), 90)

	r = _group(geo, "Room_G1")
	wall_run(r, "Wall_East", "z", 26, 0, 10, {}, "plaster")
	place(r, PROPS + "Bed.tscn", "Bed", Vector3(24, 0, 1.3))
	place(r, PROPS + "Sofa.tscn", "Sofa", Vector3(20, 0, 6.5))
	place(r, PROPS + "Table.tscn", "Table", Vector3(21, 0, 3))

	r = _group(geo, "Room_G2")
	wall_run(r, "Wall_East", "z", 34, 0, 10, {}, "plaster")
	place(r, PROPS + "Bed.tscn", "Bed", Vector3(32, 0, 1.3))
	place(r, PROPS + "Sofa.tscn", "Sofa", Vector3(28, 0, 7))
	place(r, PROPS + "Table.tscn", "Table", Vector3(29, 0, 3))
	place(r, PROPS + "RubblePile.tscn", "Rubble", Vector3(31.5, 0, 6.5))

	r = _group(geo, "Room_Security")
	wall_run(r, "Wall_East", "z", 44, 0, 12, {5: "door"}) # Z10-12: corridor's east end into Stair A
	place(r, PROPS + "CCTVDesk.tscn", "CCTVDesk", Vector3(39, 0, 1.2))
	place(r, PROPS + "Locker.tscn", "Locker", Vector3(43.5, 0, 4), -90)
	place(r, PROPS + "Locker.tscn", "Locker2", Vector3(43.5, 0, 4.7), -90)
	place(r, PROPS + "Table.tscn", "Table", Vector3(36.5, 0, 6.5), 90)

	r = _group(geo, "Room_ServiceCorridor")
	wall_run(r, "Wall_West", "z", 36, 12, 32, {7: "door"})
	wall_run(r, "Wall_East", "z", 38, 12, 32, {4: "door", 8: "door"})

	r = _group(geo, "Room_Boiler")
	wall_run(r, "Wall_Stair", "x", 12, 44, 48, {0: "door"}) # Z12 between the boiler room and Stair A
	place(r, PROPS + "Boiler.tscn", "Boiler", Vector3(41.5, 0, 17))
	place(r, PROPS + "Boiler.tscn", "Boiler2", Vector3(41.5, 0, 25))
	place(r, PROPS + "Boiler.tscn", "Boiler3", Vector3(45.5, 0, 21))
	place(r, KIT + "CoverBox.tscn", "Crate", Vector3(46, 0, 28.5))
	place(r, KIT + "CoverBox.tscn", "Crate2", Vector3(39.5, 0, 30))

	r = _group(geo, "Room_StairA")
	place(r, KIT + "StairFlight.tscn", "StairFlight", Vector3(47, 0, 11))
	place(r, KIT + "BarricadeJunk.tscn", "Junk", Vector3(45, 0, 3), 90)

# ── Lights (kit lamps; the boiler room only gets one flickering lamp) ───────
func _build_lighting(l: Node3D) -> void:
	var lamps := {
		"Lobby": [Vector3(21, 2.47, 16), Vector3(31, 2.47, 16), Vector3(21, 2.47, 28), Vector3(31, 2.47, 28)],
		"Grocery": [Vector3(4, 2.47, 18), Vector3(12, 2.47, 22), Vector3(7, 2.47, 27)],
		"Storeroom": [Vector3(5, 2.47, 6)],
		"Corridor": [Vector3(15, 2.47, 11), Vector3(27, 2.47, 11), Vector3(39, 2.47, 11)],
		"Laundry": [Vector3(14, 2.47, 5)],
		"G1": [Vector3(22, 2.47, 5)],
		"G2": [Vector3(30, 2.47, 5)],
		"Security": [Vector3(39, 2.47, 5)],
		"ServiceCorridor": [Vector3(37, 2.47, 22)],
		"StairA": [Vector3(46, 4.97, 6)],
	}
	for room in lamps:
		var i := 0
		for p in lamps[room]:
			place(l, PROPS + "CeilingLamp.tscn", "Lamp_%s_%d" % [room, i], p)
			i += 1
	place(l, PROPS + "CeilingLampFlicker.tscn", "Lamp_Boiler_Flicker", Vector3(43, 2.47, 22))

# ── Player, HUD, checkpoints, pickups, captive, exit, enemies ───────────────
func _build_gameplay() -> void:
	var player := place(level, "res://game/scenes/gameplay/player/Player.tscn", "Player", Vector3(26, 0, 37))

	var ui := CanvasLayer.new()
	ui.name = "UI"
	ui.layer = 0
	level.add_child(ui); _own(ui)
	var hud: Control = load("res://game/scenes/ui/mfw/Hud.tscn").instantiate()
	hud.name = "HUD"
	ui.add_child(hud); _own(hud)

	var cps := _group(level, "Checkpoints")
	var cp_data := [["CP1", Vector3(26, 0, 34), true], ["CP2", Vector3(5, 0, 9), false], ["CP3", Vector3(41, 0, 11), false]]
	for i in cp_data.size():
		var cp: Node3D = place(cps, PROPS + "Checkpoint.tscn", "Checkpoint%d" % (i + 1), cp_data[i][1])
		cp.checkpoint_id = cp_data[i][0]
		cp.checkpoint_order = i + 1
		cp.is_start_checkpoint = cp_data[i][2]

	var pk := _group(level, "Pickups")
	place(pk, PROPS + "AmmoStash.tscn", "Ammo_Storeroom", Vector3(1.5, 0, 1.5))
	place(pk, PROPS + "Medkit.tscn", "Medkit_G1", Vector3(25, 0, 4))
	place(pk, PROPS + "AmmoStash.tscn", "Ammo_Grocery", Vector3(10, 0.9, 28.5))
	place(pk, PROPS + "AmmoStash.tscn", "Ammo_Security", Vector3(42.5, 0, 8.5))
	place(pk, PROPS + "Medkit.tscn", "Medkit_Boiler", Vector3(47, 0, 30.5))

	var captive: Node3D = place(level, "res://game/scenes/gameplay/entities/CaptiveOfficer.tscn", "InjuredOfficer", Vector3(12.5, 0, 5), 160)
	captive.captive_id = "Officer_Reyes"
	captive.officer_name = "Officer Reyes"
	captive.rescue_lines = PackedStringArray([
		"Took a round in the leg... thanks for getting me out.",
		"Stair A is in the northeast corner. The boiler room's another way round, but it's pitch dark.",
	])

	var exit: Node3D = place(level, PROPS + "LevelExitTrigger.tscn", "LevelExitTrigger", Vector3(47, 2.5, 5))
	exit.objective_text = "Reach Stair A (northeast corner) and head upstairs"
	exit.next_level = "res://game/scenes/gameplay/levels/Floor01.tscn"

	var enc := _group(level, "Encounters")
	var zone_script := load("res://game/scripts/controllers/level/EncounterZone.gd")
	var zones := {
		"Zone_Lobby": [
			["ranged", "Ranged_Desk", Vector3(26, 0, 15.8), []],
			["ranged", "Ranged_LobbyPatrol", Vector3(19, 0, 21), [Vector3(19, 0, 21), Vector3(33, 0, 21)]],
			["ranged", "Ranged_Pillar", Vector3(33, 0, 14), []],
		],
		"Zone_Grocery": [
			["rusher", "Rusher_Aisles", Vector3(7, 0, 22), [Vector3(7, 0, 14), Vector3(7, 0, 26)]],
			["ranged", "Ranged_Shelves", Vector3(13, 0, 18), []],
		],
		"Zone_Corridor": [
			["ranged", "Ranged_Corridor", Vector3(30, 0, 11), [Vector3(14, 0, 11), Vector3(42, 0, 11)]],
			["rusher", "Rusher_G2", Vector3(30, 0, 5), []],
		],
		"Zone_Security": [
			["ranged", "Ranged_CCTV", Vector3(40, 0, 6), []],
		],
		"Zone_Boiler": [
			["rusher", "Rusher_Boiler", Vector3(44, 0, 18), [Vector3(44, 0, 15), Vector3(44, 0, 29)]],
			["rusher", "Rusher_BoilerBack", Vector3(40, 0, 28), []],
		],
	}
	for zname in zones:
		var z := _group(enc, zname)
		z.set_script(zone_script)
		z.zone_id = zname
		for e in zones[zname]:
			var path: String = "res://game/scenes/gameplay/enemies/RangedEnemy.tscn" if e[0] == "ranged" else "res://game/scenes/gameplay/enemies/RusherEnemy.tscn"
			var enemy: Node3D = place(z, path, e[1], e[2])
			if not (e[3] as Array).is_empty():
				enemy.patrol_points = Array(e[3], TYPE_VECTOR3, "", null)
