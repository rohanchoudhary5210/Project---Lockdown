class_name EnemyDebugOverlay
extends Node3D

## Project: Lockdown - Enemy Debug Visualizer (Milestone 5a)
## Toggled globally via F4. Displays:
## 1. State name above enemy head (Color-coded)
## 2. Detection meter progress bar & percentage
## 3. 3D Vision cone wireframe
## 4. 3D Last Known Position ground marker

static var global_overlay_visible: bool = false

@onready var state_label: Label3D = $StateLabel
@onready var cone_mesh: MeshInstance3D = $ConeMesh
@onready var marker_mesh: MeshInstance3D = $LastKnownMarker

var _enemy: EnemyBase = null
var _cone_material: StandardMaterial3D = null
var _marker_material: StandardMaterial3D = null
var _hearing_material: StandardMaterial3D = null
var _hearing_mesh: MeshInstance3D = null

## Services come from GameService (see GameService._inject_into_new_nodes); null when run without it.
var _debug_tools: DebugTools

func inject_services(registry: Node) -> void:
	_debug_tools = registry.get_service(&"debug") as DebugTools

func _ready() -> void:
	_enemy = get_parent() as EnemyBase
	
	_hearing_mesh = MeshInstance3D.new()
	_hearing_mesh.name = "HearingRadiusMesh"
	add_child(_hearing_mesh)
	
	_setup_materials()
	_update_visibility()
	
	var dt = _debug_tools
	if dt and dt.has_signal("ai_debug_overlay_toggled"):
		dt.ai_debug_overlay_toggled.connect(_on_overlay_toggled)

func _on_overlay_toggled(is_vis: bool) -> void:
	_update_visibility()

func _setup_materials() -> void:
	_cone_material = StandardMaterial3D.new()
	_cone_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cone_material.albedo_color = Color(1.0, 0.9, 0.2, 0.6) # Translucent yellow vision cone
	_cone_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	_marker_material = StandardMaterial3D.new()
	_marker_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_marker_material.albedo_color = Color(1.0, 0.2, 0.2, 0.8) # Red diamond marker
	
	_hearing_material = StandardMaterial3D.new()
	_hearing_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hearing_material.albedo_color = Color(0.2, 0.8, 1.0, 0.7) # Cyan hearing ring
	_hearing_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

func _process(_delta: float) -> void:
	if not visible or not _enemy or not is_instance_valid(_enemy):
		return
	
	_update_label()
	_update_cone()
	_update_marker()
	_update_hearing_ring()

func _update_label() -> void:
	if not state_label:
		return
	
	var state_str: String = _enemy.get_state_name()
	if _enemy.was_alerted_by_peer:
		state_str += " (Alerted)"
	var meter_pct: int = 0
	var los_str: String = "NO"
	var heard_str: String = "None"
	
	if _enemy.perception:
		meter_pct = int(_enemy.perception.detection_meter * 100.0)
		if _enemy.perception.has_line_of_sight:
			los_str = "YES"
		if _enemy.perception.last_heard_timer > 0.0 and _enemy.perception.last_heard_noise_radius > 0.0:
			if _enemy.perception.last_heard_noise_blocked:
				heard_str = "%.1fm (Muffled)" % _enemy.perception.last_heard_noise_radius
			else:
				heard_str = "%.1fm (Open)" % _enemy.perception.last_heard_noise_radius
	
	state_label.text = "[%s]\nDetection: %d%%\nLOS: %s\nHeard: %s" % [state_str, meter_pct, los_str, heard_str]
	
	match _enemy.current_state:
		EnemyBase.State.IDLE, EnemyBase.State.PATROL:
			state_label.modulate = Color(0.3, 0.9, 0.4) # Green
		EnemyBase.State.INVESTIGATE, EnemyBase.State.SEARCH:
			state_label.modulate = Color(1.0, 0.85, 0.2) # Yellow
		EnemyBase.State.CHASE, EnemyBase.State.ATTACK:
			state_label.modulate = Color(1.0, 0.25, 0.25) # Red
		EnemyBase.State.STUNNED:
			state_label.modulate = Color(0.2, 0.7, 1.0) # Blue
		EnemyBase.State.DEAD:
			state_label.modulate = Color(0.5, 0.5, 0.5)

func _update_cone() -> void:
	if not cone_mesh or not _enemy or not _enemy.perception:
		return
	if cone_mesh.mesh != null:
		return
	
	var p: EnemyPerception = _enemy.perception
	if not p.enemy_data:
		return
	
	var range_dist: float = minf(p.enemy_data.vision_range, 15.0) # Render up to 15m for clean display
	var half_fov_rad: float = deg_to_rad(p.enemy_data.vision_fov_degrees * 0.5)
	
	var imm := ImmediateMesh.new()
	imm.surface_begin(Mesh.PRIMITIVE_LINES)
	
	var eye_local: Vector3 = Vector3(0, 1.5, 0)
	
	# Draw Left / Right / Center rays
	var left_dir: Vector3 = Vector3(-sin(half_fov_rad), 0, -cos(half_fov_rad)) * range_dist
	var right_dir: Vector3 = Vector3(sin(half_fov_rad), 0, -cos(half_fov_rad)) * range_dist
	var center_dir: Vector3 = Vector3(0, 0, -range_dist)
	
	imm.surface_add_vertex(eye_local)
	imm.surface_add_vertex(eye_local + left_dir)
	
	imm.surface_add_vertex(eye_local)
	imm.surface_add_vertex(eye_local + right_dir)
	
	imm.surface_add_vertex(eye_local)
	imm.surface_add_vertex(eye_local + center_dir)
	
	# Connect arc
	var segments: int = 12
	var prev_pt: Vector3 = left_dir
	for i in range(1, segments + 1):
		var frac: float = float(i) / float(segments)
		var angle: float = lerpf(-half_fov_rad, half_fov_rad, frac)
		var curr_pt: Vector3 = Vector3(sin(angle), 0, -cos(angle)) * range_dist
		imm.surface_add_vertex(eye_local + prev_pt)
		imm.surface_add_vertex(eye_local + curr_pt)
		prev_pt = curr_pt
	
	imm.surface_end()
	cone_mesh.mesh = imm
	cone_mesh.material_override = _cone_material

func _update_marker() -> void:
	if not marker_mesh or not _enemy:
		return
	
	if _enemy.last_known_player_position == Vector3.ZERO or _enemy.current_state in [EnemyBase.State.IDLE, EnemyBase.State.PATROL, EnemyBase.State.DEAD]:
		marker_mesh.visible = false
		return
	
	marker_mesh.visible = true
	# Render marker at last known world position
	marker_mesh.global_position = _enemy.last_known_player_position + Vector3(0, 0.05, 0)

func _on_global_overlay_toggled(is_vis: bool) -> void:
	_update_visibility()

func _update_visibility() -> void:
	visible = global_overlay_visible
	set_process(global_overlay_visible)
	if global_overlay_visible:
		_update_cone()

func _update_hearing_ring() -> void:
	if not _hearing_mesh or not _enemy or not _enemy.perception:
		return
	
	var p: EnemyPerception = _enemy.perception
	if p.last_heard_timer <= 0.0 or p.last_heard_noise_radius <= 0.0:
		_hearing_mesh.visible = false
		return
	
	_hearing_mesh.visible = true
	var r: float = p.last_heard_noise_radius
	
	if p.last_heard_noise_blocked:
		_hearing_material.albedo_color = Color(1.0, 0.5, 0.1, 0.7) # Orange for muffled
	else:
		_hearing_material.albedo_color = Color(0.2, 0.8, 1.0, 0.7) # Cyan for open
	
	var imm := ImmediateMesh.new()
	imm.surface_begin(Mesh.PRIMITIVE_LINES)
	var segments: int = 32
	for i in range(segments):
		var a1: float = (float(i) / float(segments)) * TAU
		var a2: float = (float(i + 1) / float(segments)) * TAU
		var p1 := Vector3(cos(a1) * r, 0.05, sin(a1) * r)
		var p2 := Vector3(cos(a2) * r, 0.05, sin(a2) * r)
		imm.surface_add_vertex(p1)
		imm.surface_add_vertex(p2)
	imm.surface_end()
	_hearing_mesh.mesh = imm
	_hearing_mesh.material_override = _hearing_material
