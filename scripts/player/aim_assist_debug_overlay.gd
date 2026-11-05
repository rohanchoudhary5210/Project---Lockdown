class_name AimAssistDebugOverlay
extends Node3D

## Project: Lockdown - Aim Assist F4 Debug Overlay
## Renders the aim assist targeting cone and current target lock-on in the 3D world when F4 is active.

var _player: PlayerController = null
var _mesh_instance: MeshInstance3D = null
var _label: Label3D = null
var _imm_mesh: ImmediateMesh = null
var _cone_material: StandardMaterial3D = null
var _target_material: StandardMaterial3D = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = get_parent() as PlayerController
	if not _player:
		_player = get_tree().get_first_node_in_group("player") as PlayerController
	
	_imm_mesh = ImmediateMesh.new()
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = _imm_mesh
	add_child(_mesh_instance)
	
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font_size = 18
	_label.modulate = Color(0.2, 1.0, 0.4)
	_label.visible = false
	add_child(_label)
	
	_cone_material = StandardMaterial3D.new()
	_cone_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cone_material.albedo_color = Color(0.2, 0.8, 1.0, 0.35)
	_cone_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	_target_material = StandardMaterial3D.new()
	_target_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_target_material.albedo_color = Color(0.2, 1.0, 0.4, 0.9)
	
	_update_visibility()
	
	var dt = get_node_or_null("/root/DebugTools")
	if dt and dt.has_signal("ai_debug_overlay_toggled"):
		dt.ai_debug_overlay_toggled.connect(_on_overlay_toggled)

func _on_overlay_toggled(_is_vis: bool) -> void:
	_update_visibility()

func _update_visibility() -> void:
	var should_show = OS.is_debug_build() and EnemyDebugOverlay.global_overlay_visible
	visible = should_show
	if not should_show:
		if _imm_mesh:
			_imm_mesh.clear_surfaces()
		if _label:
			_label.visible = false

func _process(_delta: float) -> void:
	if not visible or not _player or not is_instance_valid(_player):
		return
	if not EnemyDebugOverlay.global_overlay_visible:
		_update_visibility()
		return
	
	_draw_debug_visuals()

func _draw_debug_visuals() -> void:
	if not _player.camera or not _imm_mesh:
		return
	
	_imm_mesh.clear_surfaces()
	
	var cam = _player.camera
	var cam_pos = cam.global_position
	var cam_forward = -cam.global_transform.basis.z
	var cam_right = cam.global_transform.basis.x
	var cam_up = cam.global_transform.basis.y
	
	var data: AimAssistData = _player.aim_assist_data
	var cone_angle_deg = data.assist_cone_angle_deg if data else 14.0
	var friction_angle_deg = data.friction_angle_deg if data else 4.0
	var range_dist = data.max_range if data else 25.0
	
	# Draw assist cone wireframe (outer assist cone in cyan, inner friction cone in yellow)
	_imm_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _cone_material)
	
	# Outer cone (assist detection)
	_draw_cone_wireframe(cam_pos, cam_forward, cam_right, cam_up, cone_angle_deg, range_dist, Color(0.2, 0.8, 1.0, 0.35))
	# Inner cone (friction)
	_draw_cone_wireframe(cam_pos, cam_forward, cam_right, cam_up, friction_angle_deg, range_dist, Color(1.0, 0.85, 0.2, 0.5))
	
	_imm_mesh.surface_end()
	
	# Draw current target highlight if locked
	var target = _player.current_aim_target
	if target and is_instance_valid(target) and target.is_alive():
		var chest_pos = target.get_chest_position()
		
		_imm_mesh.surface_begin(Mesh.PRIMITIVE_LINES, _target_material)
		# Line from camera to target chest
		_imm_mesh.surface_set_color(Color(0.2, 1.0, 0.4, 0.9))
		_imm_mesh.surface_add_vertex(cam_pos + cam_forward * 0.3)
		_imm_mesh.surface_add_vertex(chest_pos)
		
		# Chest marker cross / diamond
		var s: float = 0.25
		_imm_mesh.surface_add_vertex(chest_pos + Vector3(-s, 0, 0))
		_imm_mesh.surface_add_vertex(chest_pos + Vector3(s, 0, 0))
		_imm_mesh.surface_add_vertex(chest_pos + Vector3(0, -s, 0))
		_imm_mesh.surface_add_vertex(chest_pos + Vector3(0, s, 0))
		_imm_mesh.surface_add_vertex(chest_pos + Vector3(0, 0, -s))
		_imm_mesh.surface_add_vertex(chest_pos + Vector3(0, 0, s))
		_imm_mesh.surface_end()
		
		if _label:
			_label.global_position = chest_pos + Vector3(0, 0.45, 0)
			_label.text = "[AIM TARGET]\nAngle: %.1f° | Dist: %.1fm" % [_player.current_aim_target_angle_deg, _player.current_aim_target_dist]
			_label.visible = true
	else:
		if _label:
			_label.visible = false

func _draw_cone_wireframe(cam_pos: Vector3, forward: Vector3, right: Vector3, up: Vector3, angle_deg: float, dist: float, col: Color) -> void:
	var angle_rad = deg_to_rad(angle_deg)
	var radius = dist * tan(angle_rad)
	var center = cam_pos + forward * dist
	
	var segments = 16
	var prev_point = center + right * radius
	
	for i in range(1, segments + 1):
		var theta = (float(i) / float(segments)) * TAU
		var pt = center + (right * cos(theta) + up * sin(theta)) * radius
		
		_imm_mesh.surface_set_color(col)
		_imm_mesh.surface_add_vertex(prev_point)
		_imm_mesh.surface_add_vertex(pt)
		prev_point = pt
	
	# Ray lines from origin to circle edge at 4 cardinal points
	for i in range(4):
		var theta = (float(i) / 4.0) * TAU
		var pt = center + (right * cos(theta) + up * sin(theta)) * radius
		_imm_mesh.surface_set_color(col)
		_imm_mesh.surface_add_vertex(cam_pos + forward * 0.2)
		_imm_mesh.surface_add_vertex(pt)
