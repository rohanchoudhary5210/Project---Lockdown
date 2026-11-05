extends SceneTree

func _init() -> void:
	print("=== Checking Occluders in floor_01.tscn ===")
	var scn = load("res://scenes/levels/floor_01.tscn")
	var floor_inst = scn.instantiate()
	root.add_child(floor_inst)
	
	var occluders = []
	_find_occluders(floor_inst, occluders)
	print("Found total OccluderInstance3D nodes: ", occluders.size())
	
	var misaligned = 0
	var no_shape = 0
	for occ in occluders:
		var parent = occ.get_parent()
		var box = occ.occluder as BoxOccluder3D
		if not box:
			print("WARNING: Occluder has no BoxOccluder3D: ", occ.get_path())
			no_shape += 1
			continue
		
		# Check sibling mesh
		var mesh_inst: MeshInstance3D = parent.find_child("MeshInstance3D", false, false)
		if mesh_inst and mesh_inst.mesh is BoxMesh:
			var bmesh = mesh_inst.mesh as BoxMesh
			var diff = (box.size - bmesh.size).length()
			if diff > 0.01:
				print("MISMATCH size: %s | occ=%s vs mesh=%s" % [parent.name, box.size, bmesh.size])
				misaligned += 1
		
		# Check position offset
		if occ.position != Vector3.ZERO:
			print("NON-ZERO LOCAL POS: %s has occ.pos=%s" % [parent.name, occ.position])
			misaligned += 1
	
	print("Check complete: %d occluders, %d misaligned, %d without shape" % [occluders.size(), misaligned, no_shape])
	quit(0)

func _find_occluders(node: Node, list: Array) -> void:
	if node is OccluderInstance3D:
		list.append(node)
	for c in node.get_children():
		_find_occluders(c, list)
