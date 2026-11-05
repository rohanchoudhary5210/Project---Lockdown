extends SceneTree

## Tool script to generate scenes/levels/floor_01.tscn and bake data/floor_01_navmesh.tres

func _initialize() -> void:
	call_deferred("_run_build")

func _run_build() -> void:
	print("--- Starting Floor 01 Generation ---")
	
	# Load preloads - Procedural Materials (No external image files)
	var concrete_wall_mat = load("res://assets/procedural/materials/mat_concrete_wall.tres")
	var plaster_wall_mat = load("res://assets/procedural/materials/mat_plaster_wall.tres")
	var floor_mat = load("res://assets/procedural/materials/mat_tiled_floor.tres")
	var ceiling_mat = load("res://assets/procedural/materials/mat_ceiling.tres")
	var metal_mat = load("res://assets/procedural/materials/mat_metal.tres")
	var wood_mat = load("res://assets/procedural/materials/mat_wood.tres")
	var env_res = load("res://assets/placeholder/default_env.tres")
	
	var wall_segment_scene = load("res://scenes/modular/wall_segment.tscn")
	var doorway_segment_scene = load("res://scenes/modular/doorway_segment.tscn")
	var cover_box_scene = load("res://scenes/modular/cover_box.tscn")
	var barricade_junk_scene = load("res://scenes/modular/barricade_junk.tscn")
	var floor_tile_scene = load("res://scenes/modular/floor_tile.tscn")
	
	var player_scene = load("res://scenes/player/player.tscn")
	var hud_scene = load("res://scenes/ui/hud.tscn")
	var ranged_enemy_scene = load("res://scenes/enemies/ranged_enemy.tscn")
	var rusher_enemy_scene = load("res://scenes/enemies/rusher_enemy.tscn")
	var ammo_stash_scene = load("res://scenes/levels/ammo_stash.tscn")
	var medkit_scene = load("res://scenes/levels/medkit.tscn")
	var checkpoint_scene = load("res://scenes/levels/checkpoint.tscn")
	var captive_scene = load("res://scenes/entities/captive_officer.tscn")
	var exit_trigger_scene = load("res://scenes/levels/level_exit_trigger.tscn")
	var flickering_script = load("res://scripts/levels/flickering_light.gd")
	var encounter_zone_script = load("res://scripts/levels/encounter_zone.gd")
	
	var root_node = Node3D.new()
	root_node.name = "Floor01"
	root.add_child(root_node)
	
	# 1. WorldEnvironment
	var world_env = WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env_res
	root_node.add_child(world_env)
	world_env.owner = root_node
	
	# 2. DirectionalLight3D
	var dir_light = DirectionalLight3D.new()
	dir_light.name = "DirectionalLight3D"
	dir_light.transform = Transform3D(Vector3(0.866025, 0.0, -0.5), Vector3(-0.353553, 0.707107, -0.612372), Vector3(0.353553, 0.707107, 0.612372), Vector3(0.0, 10.0, 0.0))
	dir_light.light_energy = 0.25 # Moody interior ambient spill
	dir_light.shadow_enabled = false
	root_node.add_child(dir_light)
	dir_light.owner = root_node
	
	# 3. NavigationRegion3D
	var nav_region = NavigationRegion3D.new()
	nav_region.name = "NavigationRegion3D"
	root_node.add_child(nav_region)
	nav_region.owner = root_node
	
	# 4. Geometry Root (Parent for all walls, floors, ceilings, modular pieces)
	var geometry = Node3D.new()
	geometry.name = "Geometry"
	root_node.add_child(geometry)
	geometry.owner = root_node
	
	# Create 12 Room Node3D containers under Geometry for per-room culling
	var rooms = {}
	var room_names = [
		"Room_StairA",
		"Room_Corridor",
		"Room_Apt101",
		"Room_Apt102",
		"Room_Apt103",
		"Room_Storage",
		"Room_Apt104",
		"Room_Utility",
		"Room_CommonRoom",
		"Room_MeterRoom",
		"Room_ServicePassage",
		"Room_StairB"
	]
	for r_name in room_names:
		var room_node = Node3D.new()
		room_node.name = r_name
		geometry.add_child(room_node)
		room_node.owner = root_node
		rooms[r_name] = room_node
	
	# Helper lambda to add StaticBody3D box collider + mesh
	var create_box = func(parent: Node, b_name: String, pos: Vector3, size: Vector3, mat: Material, add_occluder: bool = false) -> StaticBody3D:
		var sb = StaticBody3D.new()
		sb.name = b_name
		sb.collision_layer = 1
		sb.collision_mask = 0
		sb.position = pos
		parent.add_child(sb)
		sb.owner = root_node
		
		var col = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = size
		col.shape = shape
		col.name = "CollisionShape3D"
		sb.add_child(col)
		col.owner = root_node
		
		var mi = MeshInstance3D.new()
		var mesh = BoxMesh.new()
		mesh.size = size
		mesh.material = mat
		mi.mesh = mesh
		mi.name = "MeshInstance3D"
		sb.add_child(mi)
		mi.owner = root_node
		
		if add_occluder:
			var occ_inst = OccluderInstance3D.new()
			occ_inst.name = "OccluderInstance3D"
			var box_occ = BoxOccluder3D.new()
			box_occ.size = size
			occ_inst.occluder = box_occ
			sb.add_child(occ_inst)
			occ_inst.owner = root_node
		
		return sb
	
	# Helper lambda to add wall segment
	var add_wall = func(parent: Node, pos: Vector3, rot_y: float = 0.0) -> StaticBody3D:
		var w = wall_segment_scene.instantiate()
		w.position = pos
		w.rotation.y = rot_y
		parent.add_child(w)
		w.owner = root_node
		return w
	
	# Helper lambda to add doorway segment
	var add_doorway = func(parent: Node, pos: Vector3, rot_y: float = 0.0) -> StaticBody3D:
		var d = doorway_segment_scene.instantiate()
		d.position = pos
		d.rotation.y = rot_y
		parent.add_child(d)
		d.owner = root_node
		return d
	
	# Helper lambda to add cover box
	var add_cover_box = func(parent: Node, pos: Vector3) -> StaticBody3D:
		var b = cover_box_scene.instantiate()
		b.position = pos
		parent.add_child(b)
		b.owner = root_node
		return b
	
	# Helper lambda to add barricade junk
	var add_barricade = func(parent: Node, pos: Vector3, rot_y: float = 0.0) -> StaticBody3D:
		var bj = barricade_junk_scene.instantiate()
		bj.position = pos
		bj.rotation.y = rot_y
		parent.add_child(bj)
		bj.owner = root_node
		return bj
	
	print("Building Floor & Ceilings (Split Per Room + Occlusion)...")
	# ----------------------------------------------------
	# 1. Room_StairA (X 0-4, Z 6-12, Height 5.0m)
	# ----------------------------------------------------
	create_box.call(rooms["Room_StairA"], "StairA_Floor", Vector3(2.0, -0.1, 9.0), Vector3(4.0, 0.2, 6.0), floor_mat, false)
	create_box.call(rooms["Room_StairA"], "CeilingStairA", Vector3(2.0, 5.1, 9.0), Vector3(4.0, 0.2, 6.0), ceiling_mat, false)
	create_box.call(rooms["Room_StairA"], "StairA_West", Vector3(-0.1, 2.5, 9.0), Vector3(0.2, 5.0, 6.0), concrete_wall_mat, true)
	create_box.call(rooms["Room_StairA"], "StairA_North", Vector3(2.0, 2.5, 5.9), Vector3(4.0, 5.0, 0.2), concrete_wall_mat, true)
	create_box.call(rooms["Room_StairA"], "StairA_South", Vector3(2.0, 2.5, 12.1), Vector3(4.0, 5.0, 0.2), concrete_wall_mat, true)
	create_box.call(rooms["Room_StairA"], "StairA_EastNorth", Vector3(4.0, 2.5, 6.5), Vector3(0.2, 5.0, 1.0), concrete_wall_mat, true)
	create_box.call(rooms["Room_StairA"], "StairA_EastSouth", Vector3(4.0, 2.5, 10.4), Vector3(0.2, 5.0, 3.2), concrete_wall_mat, true)
	create_box.call(rooms["Room_StairA"], "StairA_EastHeader", Vector3(4.0, 3.6, 7.9), Vector3(0.2, 2.8, 1.8), concrete_wall_mat, false)
	add_barricade.call(rooms["Room_StairA"], Vector3(1.2, 0.0, 11.2), PI / 2.0)
	add_barricade.call(rooms["Room_StairA"], Vector3(2.8, 0.0, 11.2), PI / 2.0)
	
	# ----------------------------------------------------
	# 2. Room_Corridor (X 4-32, Z 7-8.8)
	# ----------------------------------------------------
	create_box.call(rooms["Room_Corridor"], "Corridor_Floor", Vector3(18.0, -0.1, 7.9), Vector3(28.0, 0.2, 1.8), floor_mat, false)
	create_box.call(rooms["Room_Corridor"], "CeilingCorridor", Vector3(18.0, 2.6, 7.9), Vector3(28.0, 0.2, 1.8), ceiling_mat, false)
	
	# Corridor North Wall (Z = 7.0)
	create_box.call(rooms["Room_Corridor"], "CorridorNorth_4_7", Vector3(5.5, 1.25, 7.0), Vector3(3.0, 2.5, 0.2), concrete_wall_mat, true)
	add_doorway.call(rooms["Room_Corridor"], Vector3(8.0, 0.0, 7.0))
	create_box.call(rooms["Room_Corridor"], "CorridorNorth_9_15", Vector3(12.0, 1.25, 7.0), Vector3(6.0, 2.5, 0.2), concrete_wall_mat, true)
	add_doorway.call(rooms["Room_Corridor"], Vector3(16.0, 0.0, 7.0))
	create_box.call(rooms["Room_Corridor"], "CorridorNorth_17_29", Vector3(23.0, 1.25, 7.0), Vector3(12.0, 2.5, 0.2), concrete_wall_mat, true)
	add_doorway.call(rooms["Room_Corridor"], Vector3(30.0, 0.0, 7.0))
	create_box.call(rooms["Room_Corridor"], "CorridorNorth_31_32", Vector3(31.5, 1.25, 7.0), Vector3(1.0, 2.5, 0.2), concrete_wall_mat, true)
	
	# Corridor South Wall (Z = 8.8)
	create_box.call(rooms["Room_Corridor"], "CorridorSouth_4_8", Vector3(6.0, 1.25, 8.8), Vector3(4.0, 2.5, 0.2), concrete_wall_mat, true)
	add_doorway.call(rooms["Room_Corridor"], Vector3(9.0, 0.0, 8.8))
	create_box.call(rooms["Room_Corridor"], "CorridorSouth_10_14.5", Vector3(12.25, 1.25, 8.8), Vector3(4.5, 2.5, 0.2), concrete_wall_mat, true)
	add_doorway.call(rooms["Room_Corridor"], Vector3(15.5, 0.0, 8.8))
	create_box.call(rooms["Room_Corridor"], "CorridorSouth_16.5_21", Vector3(18.75, 1.25, 8.8), Vector3(4.5, 2.5, 0.2), concrete_wall_mat, true)
	add_doorway.call(rooms["Room_Corridor"], Vector3(22.0, 0.0, 8.8))
	create_box.call(rooms["Room_Corridor"], "CorridorSouth_23_32", Vector3(27.5, 1.25, 8.8), Vector3(9.0, 2.5, 0.2), concrete_wall_mat, true)
	
	# Corridor Barricades
	add_barricade.call(rooms["Room_Corridor"], Vector3(13.0, 0.0, 7.45))
	add_barricade.call(rooms["Room_Corridor"], Vector3(25.0, 0.0, 8.35))
	add_barricade.call(rooms["Room_Corridor"], Vector3(30.0, 0.0, 7.5))
	
	# ----------------------------------------------------
	# 3. Room_Apt101 (X 4-12, Z 0-7)
	# ----------------------------------------------------
	create_box.call(rooms["Room_Apt101"], "Apt101_Floor", Vector3(8.0, -0.1, 3.5), Vector3(8.0, 0.2, 7.0), floor_mat, false)
	create_box.call(rooms["Room_Apt101"], "Apt101_Ceiling", Vector3(8.0, 2.6, 3.5), Vector3(8.0, 0.2, 7.0), ceiling_mat, false)
	create_box.call(rooms["Room_Apt101"], "Apt101_OuterNorth", Vector3(8.0, 1.25, -0.1), Vector3(8.0, 2.5, 0.2), plaster_wall_mat, true)
	create_box.call(rooms["Room_Apt101"], "Apt101_OuterWest", Vector3(3.9, 1.25, 3.0), Vector3(0.2, 2.5, 6.0), plaster_wall_mat, true)
	create_box.call(rooms["Room_Apt101"], "Wall_Apt101_102", Vector3(12.0, 1.25, 3.5), Vector3(0.2, 2.5, 7.0), plaster_wall_mat, true)
	create_box.call(rooms["Room_Apt101"], "Partition_Apt101", Vector3(8.0, 1.25, 1.8), Vector3(0.2, 2.5, 3.6), plaster_wall_mat, true)
	add_cover_box.call(rooms["Room_Apt101"], Vector3(6.0, 0.0, 3.5))
	add_cover_box.call(rooms["Room_Apt101"], Vector3(10.0, 0.0, 5.0))
	
	# ----------------------------------------------------
	# 4. Room_Apt102 (X 12-20, Z 0-7)
	# ----------------------------------------------------
	create_box.call(rooms["Room_Apt102"], "Apt102_Floor", Vector3(16.0, -0.1, 3.5), Vector3(8.0, 0.2, 7.0), floor_mat, false)
	create_box.call(rooms["Room_Apt102"], "Apt102_Ceiling", Vector3(16.0, 2.6, 3.5), Vector3(8.0, 0.2, 7.0), ceiling_mat, false)
	create_box.call(rooms["Room_Apt102"], "Apt102_OuterNorth", Vector3(16.0, 1.25, -0.1), Vector3(8.0, 2.5, 0.2), plaster_wall_mat, true)
	create_box.call(rooms["Room_Apt102"], "Wall_Apt102_103_North", Vector3(20.0, 1.25, 1.0), Vector3(0.2, 2.5, 2.0), plaster_wall_mat, true)
	create_box.call(rooms["Room_Apt102"], "Wall_Apt102_103_South", Vector3(20.0, 1.25, 5.0), Vector3(0.2, 2.5, 4.0), plaster_wall_mat, true)
	add_cover_box.call(rooms["Room_Apt102"], Vector3(20.0, 0.0, 1.7))
	create_box.call(rooms["Room_Apt102"], "Partition_Apt102", Vector3(16.0, 1.25, 1.8), Vector3(0.2, 2.5, 3.6), plaster_wall_mat, true)
	add_cover_box.call(rooms["Room_Apt102"], Vector3(14.0, 0.0, 3.5))
	add_cover_box.call(rooms["Room_Apt102"], Vector3(18.0, 0.0, 5.0))
	
	# ----------------------------------------------------
	# 5. Room_Apt103 (X 20-28, Z 0-7)
	# ----------------------------------------------------
	create_box.call(rooms["Room_Apt103"], "Apt103_Floor", Vector3(24.0, -0.1, 3.5), Vector3(8.0, 0.2, 7.0), floor_mat, false)
	create_box.call(rooms["Room_Apt103"], "Apt103_Ceiling", Vector3(24.0, 2.6, 3.5), Vector3(8.0, 0.2, 7.0), ceiling_mat, false)
	create_box.call(rooms["Room_Apt103"], "Apt103_OuterNorth", Vector3(24.0, 1.25, -0.1), Vector3(8.0, 2.5, 0.2), plaster_wall_mat, true)
	create_box.call(rooms["Room_Apt103"], "Wall_Apt103_Storage", Vector3(28.0, 1.25, 3.5), Vector3(0.2, 2.5, 7.0), plaster_wall_mat, true)
	create_box.call(rooms["Room_Apt103"], "Partition_Apt103", Vector3(24.0, 1.25, 1.8), Vector3(0.2, 2.5, 3.6), plaster_wall_mat, true)
	add_cover_box.call(rooms["Room_Apt103"], Vector3(22.0, 0.0, 3.5))
	add_cover_box.call(rooms["Room_Apt103"], Vector3(26.0, 0.0, 5.0))
	
	# ----------------------------------------------------
	# 6. Room_Storage (X 28-32, Z 0-7)
	# ----------------------------------------------------
	create_box.call(rooms["Room_Storage"], "Storage_Floor", Vector3(30.0, -0.1, 3.5), Vector3(4.0, 0.2, 7.0), floor_mat, false)
	create_box.call(rooms["Room_Storage"], "Storage_Ceiling", Vector3(30.0, 2.6, 3.5), Vector3(4.0, 0.2, 7.0), ceiling_mat, false)
	create_box.call(rooms["Room_Storage"], "Storage_OuterNorth", Vector3(30.0, 1.25, -0.1), Vector3(4.0, 2.5, 0.2), concrete_wall_mat, true)
	create_box.call(rooms["Room_Storage"], "OuterEastStorage", Vector3(32.1, 1.25, 2.0), Vector3(0.2, 2.5, 4.0), concrete_wall_mat, true)
	add_cover_box.call(rooms["Room_Storage"], Vector3(30.0, 0.0, 2.5))
	add_cover_box.call(rooms["Room_Storage"], Vector3(30.0, 0.0, 4.5))
	
	# ----------------------------------------------------
	# 7. Room_Apt104 (X 4-14, Z 8.8-16)
	# ----------------------------------------------------
	create_box.call(rooms["Room_Apt104"], "Apt104_Floor", Vector3(9.0, -0.1, 12.4), Vector3(10.0, 0.2, 7.2), floor_mat, false)
	create_box.call(rooms["Room_Apt104"], "Apt104_Ceiling", Vector3(9.0, 2.6, 12.4), Vector3(10.0, 0.2, 7.2), ceiling_mat, false)
	create_box.call(rooms["Room_Apt104"], "Apt104_OuterSouth", Vector3(9.0, 1.25, 16.1), Vector3(10.0, 2.5, 0.2), plaster_wall_mat, true)
	create_box.call(rooms["Room_Apt104"], "OuterWestApt104", Vector3(3.9, 1.25, 14.0), Vector3(0.2, 2.5, 4.0), plaster_wall_mat, true)
	create_box.call(rooms["Room_Apt104"], "Wall_Apt104_Utility", Vector3(14.0, 1.25, 12.4), Vector3(0.2, 2.5, 7.2), plaster_wall_mat, true)
	create_box.call(rooms["Room_Apt104"], "Partition_Apt104", Vector3(9.0, 1.25, 14.2), Vector3(0.2, 2.5, 3.6), plaster_wall_mat, true)
	add_cover_box.call(rooms["Room_Apt104"], Vector3(7.0, 0.0, 11.0))
	add_cover_box.call(rooms["Room_Apt104"], Vector3(11.0, 0.0, 13.0))
	
	# ----------------------------------------------------
	# 8. Room_Utility (X 14-17, Z 8.8-14)
	# ----------------------------------------------------
	create_box.call(rooms["Room_Utility"], "Utility_Floor", Vector3(15.5, -0.1, 11.4), Vector3(3.0, 0.2, 5.2), floor_mat, false)
	create_box.call(rooms["Room_Utility"], "Utility_Ceiling", Vector3(15.5, 2.6, 11.4), Vector3(3.0, 0.2, 5.2), ceiling_mat, false)
	create_box.call(rooms["Room_Utility"], "Wall_Utility_Common_North", Vector3(17.0, 1.25, 9.4), Vector3(0.2, 2.5, 1.2), concrete_wall_mat, true)
	add_doorway.call(rooms["Room_Utility"], Vector3(17.0, 0.0, 11.0), PI / 2.0)
	create_box.call(rooms["Room_Utility"], "Wall_Utility_Common_South", Vector3(17.0, 1.25, 13.0), Vector3(0.2, 2.5, 2.0), concrete_wall_mat, true)
	create_box.call(rooms["Room_Utility"], "Wall_Passage_14_14.5", Vector3(14.25, 1.25, 14.0), Vector3(0.5, 2.5, 0.2), concrete_wall_mat, false)
	add_doorway.call(rooms["Room_Utility"], Vector3(15.5, 0.0, 14.0))
	create_box.call(rooms["Room_Utility"], "Wall_Passage_16.5_17", Vector3(16.75, 1.25, 14.0), Vector3(0.5, 2.5, 0.2), concrete_wall_mat, false)
	
	# ----------------------------------------------------
	# 9. Room_CommonRoom (X 17-28, Z 8.8-14)
	# ----------------------------------------------------
	create_box.call(rooms["Room_CommonRoom"], "CommonRoom_Floor", Vector3(22.5, -0.1, 11.4), Vector3(11.0, 0.2, 5.2), floor_mat, false)
	create_box.call(rooms["Room_CommonRoom"], "CommonRoom_Ceiling", Vector3(22.5, 2.6, 11.4), Vector3(11.0, 0.2, 5.2), ceiling_mat, false)
	create_box.call(rooms["Room_CommonRoom"], "Wall_CommonRoom_South", Vector3(22.5, 1.25, 14.0), Vector3(11.0, 2.5, 0.2), plaster_wall_mat, true)
	create_box.call(rooms["Room_CommonRoom"], "Wall_Common_Meter", Vector3(28.0, 1.25, 11.4), Vector3(0.2, 2.5, 5.2), plaster_wall_mat, true)
	add_cover_box.call(rooms["Room_CommonRoom"], Vector3(21.0, 0.0, 10.0))
	add_cover_box.call(rooms["Room_CommonRoom"], Vector3(23.5, 0.0, 12.5))
	add_cover_box.call(rooms["Room_CommonRoom"], Vector3(26.0, 0.0, 11.2))
	
	# ----------------------------------------------------
	# 10. Room_MeterRoom (X 28-32, Z 8.8-14)
	# ----------------------------------------------------
	create_box.call(rooms["Room_MeterRoom"], "MeterRoom_Floor", Vector3(30.0, -0.1, 11.4), Vector3(4.0, 0.2, 5.2), floor_mat, false)
	create_box.call(rooms["Room_MeterRoom"], "MeterRoom_Ceiling", Vector3(30.0, 2.6, 11.4), Vector3(4.0, 0.2, 5.2), ceiling_mat, false)
	create_box.call(rooms["Room_MeterRoom"], "Wall_MeterRoom_South", Vector3(30.0, 1.25, 14.0), Vector3(4.0, 2.5, 0.2), concrete_wall_mat, true)
	
	# ----------------------------------------------------
	# 11. Room_ServicePassage (X 14-36, Z 14-16)
	# ----------------------------------------------------
	create_box.call(rooms["Room_ServicePassage"], "Passage_Floor_Main", Vector3(23.0, -0.1, 15.0), Vector3(18.0, 0.2, 2.0), floor_mat, false)
	create_box.call(rooms["Room_ServicePassage"], "Passage_Ceiling_Main", Vector3(23.0, 2.6, 15.0), Vector3(18.0, 0.2, 2.0), ceiling_mat, false)
	create_box.call(rooms["Room_ServicePassage"], "Passage_Floor_Ext", Vector3(34.0, -0.1, 14.0), Vector3(4.0, 0.2, 4.0), floor_mat, false)
	create_box.call(rooms["Room_ServicePassage"], "Passage_Ceiling_Ext", Vector3(34.0, 2.6, 14.0), Vector3(4.0, 0.2, 4.0), ceiling_mat, false)
	create_box.call(rooms["Room_ServicePassage"], "OuterSouthPassage", Vector3(23.0, 1.25, 16.1), Vector3(18.0, 2.5, 0.2), concrete_wall_mat, true)
	create_box.call(rooms["Room_ServicePassage"], "OuterSouthPassageExt", Vector3(34.0, 1.25, 16.1), Vector3(4.0, 2.5, 0.2), concrete_wall_mat, true)
	create_box.call(rooms["Room_ServicePassage"], "OuterEastPassageExt", Vector3(36.1, 1.25, 14.0), Vector3(0.2, 2.5, 4.0), concrete_wall_mat, true)
	
	# ----------------------------------------------------
	# 12. Room_StairB (X 32-36, Z 4-12, Height 5.0m)
	# ----------------------------------------------------
	create_box.call(rooms["Room_StairB"], "StairB_Floor", Vector3(34.0, -0.1, 8.0), Vector3(4.0, 0.2, 8.0), floor_mat, false)
	create_box.call(rooms["Room_StairB"], "CeilingStairB", Vector3(34.0, 5.1, 8.0), Vector3(4.0, 0.2, 8.0), ceiling_mat, false)
	create_box.call(rooms["Room_StairB"], "StairB_East", Vector3(36.1, 2.5, 8.0), Vector3(0.2, 5.0, 8.0), concrete_wall_mat, true)
	create_box.call(rooms["Room_StairB"], "StairB_North", Vector3(34.0, 2.5, 3.9), Vector3(4.0, 5.0, 0.2), concrete_wall_mat, true)
	create_box.call(rooms["Room_StairB"], "StairB_WestNorth", Vector3(32.0, 2.5, 5.5), Vector3(0.2, 5.0, 3.0), concrete_wall_mat, true)
	create_box.call(rooms["Room_StairB"], "StairB_WestSouth", Vector3(32.0, 2.5, 10.4), Vector3(0.2, 5.0, 3.2), concrete_wall_mat, true)
	create_box.call(rooms["Room_StairB"], "StairB_WestHeader", Vector3(32.0, 3.6, 7.9), Vector3(0.2, 2.8, 1.8), concrete_wall_mat, false)
	create_box.call(rooms["Room_StairB"], "StairB_SouthLeft", Vector3(32.75, 2.5, 12.0), Vector3(1.5, 5.0, 0.2), concrete_wall_mat, true)
	create_box.call(rooms["Room_StairB"], "StairB_SouthRight", Vector3(35.25, 2.5, 12.0), Vector3(1.5, 5.0, 0.2), concrete_wall_mat, true)
	create_box.call(rooms["Room_StairB"], "StairB_SouthHeader", Vector3(34.0, 3.6, 12.0), Vector3(1.0, 2.8, 0.2), concrete_wall_mat, false)
	create_box.call(rooms["Room_StairB"], "StairB_ElevatedLanding", Vector3(34.0, 1.8, 4.75), Vector3(4.0, 0.4, 1.5), floor_mat, false)
	create_box.call(rooms["Room_StairB"], "StairB_Step1", Vector3(34.0, 0.2, 7.25), Vector3(3.6, 0.4, 0.5), metal_mat, false)
	create_box.call(rooms["Room_StairB"], "StairB_Step2", Vector3(34.0, 0.6, 6.75), Vector3(3.6, 0.4, 0.5), metal_mat, false)
	create_box.call(rooms["Room_StairB"], "StairB_Step3", Vector3(34.0, 1.0, 6.25), Vector3(3.6, 0.4, 0.5), metal_mat, false)
	create_box.call(rooms["Room_StairB"], "StairB_Step4", Vector3(34.0, 1.4, 5.75), Vector3(3.6, 0.4, 0.5), metal_mat, false)
	
	print("Adding Lighting...")
	# ----------------------------------------------------
	# LIGHTING
	# Corridor lights every ~6m: X = 6, 12, 18, 24, 30 at Y = 2.3, Z = 7.9
	# X = 18 is FlickeringLight
	# Common room brighter (2 lights)
	# Stair B lit from above (elevated shooter visible)
	# ----------------------------------------------------
	var lights_root = Node3D.new()
	lights_root.name = "Lighting"
	root_node.add_child(lights_root)
	lights_root.owner = root_node
	
	var add_light = func(pos: Vector3, energy: float = 0.8, range_val: float = 8.0, is_flicker: bool = false, shadow: bool = false) -> OmniLight3D:
		var light: OmniLight3D
		if is_flicker:
			light = OmniLight3D.new()
			light.set_script(flickering_script)
		else:
			light = OmniLight3D.new()
		light.position = pos
		light.light_energy = energy
		light.omni_range = range_val
		light.shadow_enabled = shadow
		lights_root.add_child(light)
		light.owner = root_node
		return light
	
	add_light.call(Vector3(6.0, 2.3, 7.9), 0.7, 5.5, false, false)
	add_light.call(Vector3(12.0, 2.3, 7.9), 0.7, 5.5, false, false)
	add_light.call(Vector3(18.0, 2.3, 7.9), 0.85, 5.5, true, true) # Flickering at X = 18 (Shadows ON)
	add_light.call(Vector3(24.0, 2.3, 7.9), 0.7, 5.5, false, false)
	add_light.call(Vector3(30.0, 2.3, 7.9), 0.7, 5.5, false, false)
	
	# Common room (one with shadows ON, one without)
	add_light.call(Vector3(20.0, 2.3, 11.0), 1.2, 9.0, false, true) # Shadows ON
	add_light.call(Vector3(25.0, 2.3, 12.0), 1.0, 8.5, false, false)
	
	# Stair B (lit from above so elevated shooter is clearly visible)
	add_light.call(Vector3(34.0, 4.5, 6.5), 1.6, 10.0, false, false)
	
	# Ambient lights in other rooms
	add_light.call(Vector3(2.0, 3.5, 9.0), 0.8, 6.0, false, false) # Stair A
	add_light.call(Vector3(8.0, 2.3, 3.5), 0.6, 6.0, false, false) # Apt 101
	add_light.call(Vector3(16.0, 2.3, 3.5), 0.6, 6.0, false, false) # Apt 102
	add_light.call(Vector3(24.0, 2.3, 3.5), 0.7, 6.0, false, false) # Apt 103 (Walker)
	add_light.call(Vector3(9.0, 2.3, 12.0), 0.6, 6.0, false, false) # Apt 104
	add_light.call(Vector3(15.5, 2.3, 11.5), 0.7, 6.0, false, false) # Utility
	add_light.call(Vector3(24.0, 2.3, 15.0), 0.5, 7.0, false, false) # Service Passage
	
	print("Adding Checkpoints...")
	# ----------------------------------------------------
	# CHECKPOINTS
	# CP1: Stair A at (2, 0, 10)
	# CP2: Main corridor at (27, 0, 8), after Common room
	# ----------------------------------------------------
	var cp1 = checkpoint_scene.instantiate()
	cp1.name = "Checkpoint1"
	cp1.checkpoint_id = "CP1"
	cp1.checkpoint_order = 1
	cp1.is_start_checkpoint = true
	cp1.position = Vector3(2.0, 0.0, 10.0)
	root_node.add_child(cp1)
	cp1.owner = root_node
	
	var cp2 = checkpoint_scene.instantiate()
	cp2.name = "Checkpoint2"
	cp2.checkpoint_id = "CP2"
	cp2.checkpoint_order = 2
	cp2.position = Vector3(27.0, 0.0, 8.0)
	root_node.add_child(cp2)
	cp2.owner = root_node
	
	print("Adding Pickups...")
	# ----------------------------------------------------
	# PICKUPS
	# Ammo in Apt 101: (6, 0, 2)
	# Medkit in Apt 104: (6, 0, 12)
	# Ammo + Medkit in Utility: (15.5, 0, 10) and (15.5, 0, 12.5)
	# ----------------------------------------------------
	var ammo_101 = ammo_stash_scene.instantiate()
	ammo_101.name = "Ammo_Apt101"
	ammo_101.position = Vector3(6.0, 0.0, 2.0)
	root_node.add_child(ammo_101)
	ammo_101.owner = root_node
	
	var medkit_104 = medkit_scene.instantiate()
	medkit_104.name = "Medkit_Apt104"
	medkit_104.position = Vector3(6.0, 0.0, 12.0)
	root_node.add_child(medkit_104)
	medkit_104.owner = root_node
	
	var ammo_utility = ammo_stash_scene.instantiate()
	ammo_utility.name = "Ammo_Utility"
	ammo_utility.position = Vector3(15.5, 0.0, 10.0)
	root_node.add_child(ammo_utility)
	ammo_utility.owner = root_node
	
	var medkit_utility = medkit_scene.instantiate()
	medkit_utility.name = "Medkit_Utility"
	medkit_utility.position = Vector3(15.5, 0.0, 12.5)
	root_node.add_child(medkit_utility)
	medkit_utility.owner = root_node
	
	print("Adding Captive Officer Walker...")
	# ----------------------------------------------------
	# CAPTIVE OFFICER WALKER in Apt 103 at (24, 0, 3)
	# ----------------------------------------------------
	var captive = captive_scene.instantiate()
	captive.name = "CaptiveOfficer"
	captive.captive_id = "Officer_Walker"
	captive.officer_name = "Officer Walker"
	captive.position = Vector3(24.0, 0.0, 3.0)
	root_node.add_child(captive)
	captive.owner = root_node
	
	print("Adding Exit Trigger...")
	# ----------------------------------------------------
	# LEVEL EXIT TRIGGER at top of Stair B (34, 2.0, 4.8)
	# ----------------------------------------------------
	var exit_trig = exit_trigger_scene.instantiate()
	exit_trig.name = "LevelExitTrigger"
	exit_trig.position = Vector3(34.0, 2.0, 4.8)
	root_node.add_child(exit_trig)
	exit_trig.owner = root_node
	
	print("Adding Encounters (EncounterZones & 7 Enemies)...")
	# ----------------------------------------------------
	# ENCOUNTERS (4 EncounterZones, 7 Enemies)
	# ----------------------------------------------------
	var encounters_root = Node3D.new()
	encounters_root.name = "Encounters"
	root_node.add_child(encounters_root)
	encounters_root.owner = root_node
	
	# Zone E1: Corridor Intro (1 ranged patrolling X 6..12)
	var zone_e1 = Node3D.new()
	zone_e1.name = "Zone_E1"
	zone_e1.set_script(encounter_zone_script)
	zone_e1.zone_id = "Zone_E1"
	encounters_root.add_child(zone_e1)
	zone_e1.owner = root_node
	
	var enemy_e1 = ranged_enemy_scene.instantiate()
	enemy_e1.name = "Ranged_E1"
	enemy_e1.position = Vector3(8.0, 0.0, 7.9)
	var e1_pts: Array[Vector3] = [Vector3(6.0, 0.0, 7.9), Vector3(12.0, 0.0, 7.9)]
	enemy_e1.patrol_points = e1_pts
	zone_e1.add_child(enemy_e1)
	enemy_e1.owner = root_node
	
	# Zone E2: Apt 102 (1 ranged guarding near (16, 0, 3) facing door)
	var zone_e2 = Node3D.new()
	zone_e2.name = "Zone_E2"
	zone_e2.set_script(encounter_zone_script)
	zone_e2.zone_id = "Zone_E2"
	encounters_root.add_child(zone_e2)
	zone_e2.owner = root_node
	
	var enemy_e2 = ranged_enemy_scene.instantiate()
	enemy_e2.name = "Ranged_E2"
	enemy_e2.position = Vector3(16.0, 0.0, 3.0)
	enemy_e2.rotation.y = PI # Facing south towards door
	zone_e2.add_child(enemy_e2)
	enemy_e2.owner = root_node
	
	# Zone E3: Common Room Arena (1 rusher + 2 ranged)
	var zone_e3 = Node3D.new()
	zone_e3.name = "Zone_E3"
	zone_e3.set_script(encounter_zone_script)
	zone_e3.zone_id = "Zone_E3"
	encounters_root.add_child(zone_e3)
	zone_e3.owner = root_node
	
	var rusher_e3 = rusher_enemy_scene.instantiate()
	rusher_e3.name = "Rusher_E3"
	rusher_e3.position = Vector3(20.0, 0.0, 11.0)
	zone_e3.add_child(rusher_e3)
	rusher_e3.owner = root_node
	
	var ranged_e3_1 = ranged_enemy_scene.instantiate()
	ranged_e3_1.name = "Ranged_E3_1"
	ranged_e3_1.position = Vector3(25.0, 0.0, 10.0)
	ranged_e3_1.rotation.y = -PI * 0.75 # Facing entrances
	zone_e3.add_child(ranged_e3_1)
	ranged_e3_1.owner = root_node
	
	var ranged_e3_2 = ranged_enemy_scene.instantiate()
	ranged_e3_2.name = "Ranged_E3_2"
	ranged_e3_2.position = Vector3(26.5, 0.0, 12.8)
	ranged_e3_2.rotation.y = -PI * 0.75
	zone_e3.add_child(ranged_e3_2)
	ranged_e3_2.owner = root_node
	
	# Zone E4: Stair B (1 ranged at (30.5, 0, 7.6), 1 ranged on landing at (34, 2.0, 5.5))
	var zone_e4 = Node3D.new()
	zone_e4.name = "Zone_E4"
	zone_e4.set_script(encounter_zone_script)
	zone_e4.zone_id = "Zone_E4"
	encounters_root.add_child(zone_e4)
	zone_e4.owner = root_node
	
	var ranged_e4_corridor = ranged_enemy_scene.instantiate()
	ranged_e4_corridor.name = "Ranged_E4_Corridor"
	ranged_e4_corridor.position = Vector3(30.5, 0.0, 7.6)
	ranged_e4_corridor.rotation.y = -PI / 2.0 # Facing west towards player approach
	zone_e4.add_child(ranged_e4_corridor)
	ranged_e4_corridor.owner = root_node
	
	var ranged_e4_landing = ranged_enemy_scene.instantiate()
	ranged_e4_landing.name = "Ranged_E4_Landing"
	ranged_e4_landing.position = Vector3(34.0, 2.0, 5.5)
	ranged_e4_landing.rotation.y = 0.0 # Facing south towards stair entrances
	zone_e4.add_child(ranged_e4_landing)
	ranged_e4_landing.owner = root_node
	
	print("Adding Player and HUD...")
	# ----------------------------------------------------
	# PLAYER & HUD
	# Player starts at (2, 0, 9) facing East towards corridor (-PI/2)
	# ----------------------------------------------------
	var player = player_scene.instantiate()
	player.name = "Player"
	player.position = Vector3(2.0, 0.0, 9.0)
	player.rotation.y = -PI / 2.0
	root_node.add_child(player)
	player.owner = root_node
	
	var hud_layer = CanvasLayer.new()
	hud_layer.name = "UI"
	hud_layer.layer = 0
	root_node.add_child(hud_layer)
	hud_layer.owner = root_node
	
	var hud = hud_scene.instantiate()
	hud.name = "HUD"
	hud_layer.add_child(hud)
	hud.owner = root_node
	
	print("Baking Navigation Mesh for Floor 01...")
	# ----------------------------------------------------
	# BAKING NAVMESH
	# ----------------------------------------------------
	var nav_mesh = NavigationMesh.new()
	nav_mesh.agent_height = 1.75
	nav_mesh.agent_radius = 0.4
	nav_mesh.agent_max_climb = 0.5
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_collision_mask = 1 # layer 1: world
	nav_mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	
	var source_geo = NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav_mesh, source_geo, root_node)
	NavigationServer3D.bake_from_source_geometry_data(nav_mesh, source_geo)
	
	print("Baked Navmesh: %d vertices, %d polygons" % [nav_mesh.get_vertices().size(), nav_mesh.get_polygon_count()])
	var nav_save_err = ResourceSaver.save(nav_mesh, "res://data/floor_01_navmesh.tres")
	print("Navmesh save status: ", nav_save_err)
	
	# Assign navigation_mesh to NavigationRegion3D
	nav_region.navigation_mesh = nav_mesh
	
	print("Packing and Saving scenes/levels/floor_01.tscn...")
	var packed_scene = PackedScene.new()
	var pack_err = packed_scene.pack(root_node)
	print("Scene pack status: ", pack_err)
	
	var save_err = ResourceSaver.save(packed_scene, "res://scenes/levels/floor_01.tscn")
	print("Scene save status: ", save_err)
	
	root_node.queue_free()
	print("--- Floor 01 Generation Completed Successfully! ---")
	quit(0)
