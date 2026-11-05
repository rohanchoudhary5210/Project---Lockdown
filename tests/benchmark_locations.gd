extends SceneTree

const LOCATIONS = [
	{
		"name": "Corridor Start",
		"pos": Vector3(5.0, 1.6, 7.9),
		"rot_y": -PI / 2.0 # Looking along +X
	},
	{
		"name": "Common Room",
		"pos": Vector3(22.5, 1.6, 11.5),
		"rot_y": 0.0 # Looking into room
	},
	{
		"name": "Stair B",
		"pos": Vector3(34.0, 1.6, 8.0),
		"rot_y": -PI / 2.0 # Looking toward stairs
	}
]

var _current_loc_idx = 0
var _frame_count = 0
var _warmup_frames = 30
var _sample_frames = 60
var _fps_samples: Array[float] = []
var _time_samples: Array[float] = []
var _draw_call_samples: Array[int] = []
var _object_samples: Array[int] = []

var _level_scene: Node = null
var _player: Node3D = null

func _init() -> void:
	print("=== Starting Benchmark at 3 Key Locations ===")
	call_deferred("_setup")

func _setup() -> void:
	var scn = load("res://scenes/levels/floor_01.tscn")
	_level_scene = scn.instantiate()
	root.add_child(_level_scene)
	
	_player = _level_scene.find_child("Player", true, false)
	if not _player:
		_player = root.get_node_or_null("Floor01/Player")
	
	_teleport_to_location(0)

func _teleport_to_location(idx: int) -> void:
	_current_loc_idx = idx
	_frame_count = 0
	_fps_samples.clear()
	_time_samples.clear()
	_draw_call_samples.clear()
	_object_samples.clear()
	
	var loc = LOCATIONS[idx]
	if _player:
		if _player.has_method("teleport"):
			_player.teleport(loc.pos, loc.rot_y, 0.0)
		else:
			_player.global_position = loc.pos
			_player.rotation.y = loc.rot_y
			_player.reset_physics_interpolation()
			var pivot = _player.get_node_or_null("CameraPivot")
			if pivot:
				pivot.global_position = loc.pos + Vector3(0.0, 1.6, 0.0)
				pivot.rotation.x = 0.0
				pivot.reset_physics_interpolation()

func _process(delta: float) -> bool:
	_frame_count += 1
	if _frame_count <= _warmup_frames:
		return false
	
	var fps = Performance.get_monitor(Performance.TIME_FPS)
	var frame_ms = delta * 1000.0
	var dc = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var obj = int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	
	_fps_samples.append(fps)
	_time_samples.append(frame_ms)
	_draw_call_samples.append(dc)
	_object_samples.append(obj)
	
	if _frame_count >= _warmup_frames + _sample_frames:
		_report_location(_current_loc_idx)
		if _current_loc_idx + 1 < LOCATIONS.size():
			_teleport_to_location(_current_loc_idx + 1)
		else:
			print("=== Benchmark Complete ===")
			quit(0)
			return true
	
	return false

func _report_location(idx: int) -> void:
	var loc = LOCATIONS[idx]
	var avg_fps = 0.0
	var avg_ms = 0.0
	var avg_dc = 0.0
	var avg_obj = 0.0
	for i in range(_fps_samples.size()):
		avg_fps += _fps_samples[i]
		avg_ms += _time_samples[i]
		avg_dc += _draw_call_samples[i]
		avg_obj += _object_samples[i]
	avg_fps /= _fps_samples.size()
	avg_ms /= _time_samples.size()
	avg_dc /= _fps_samples.size()
	avg_obj /= _object_samples.size()
	
	print("[RESULT] %s: FPS=%.1f | Frame=%.2f ms | Draw Calls=%d | Objects=%d" % [loc.name, avg_fps, avg_ms, int(avg_dc), int(avg_obj)])
