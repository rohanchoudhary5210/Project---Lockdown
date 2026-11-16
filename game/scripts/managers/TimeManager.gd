class_name TimeManager
extends Node

## TimeManager handles hitstop (micro time freeze on impacts) and global time dilation.
## Non-stacking: a new hitstop extends the current one, and time_scale is always restored to 1.0.
## Seamlessly preserves hitstop state across tree pauses, restoring Engine.time_scale to 1.0
## during pause for responsive UI and resuming remaining hitstop upon unpause.

var _hitstop_end_time_ms: int = 0
var _is_hitstop_active: bool = false
var _active_hitstop_scale: float = 0.05
var _remaining_hitstop_ms: int = 0

## Services come from GameService (see GameService._inject_into_new_nodes); null when run without it.
var _input_manager: InputManager

func inject_services(registry: Node) -> void:
	_input_manager = registry.get_service(&"input") as InputManager

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	
	call_deferred("_connect_input_manager")

func _connect_input_manager() -> void:
	var im: Node = _input_manager
	if im and im.has_signal("pause_toggled"):
		im.pause_toggled.connect(_on_pause_toggled)

func hitstop(duration: float = 0.03, time_scale: float = 0.05) -> void:
	var duration_ms: int = int(duration * 1000.0)
	_active_hitstop_scale = time_scale
	
	if get_tree() and get_tree().paused:
		# If paused, queue hitstop for when gameplay resumes
		_remaining_hitstop_ms = max(_remaining_hitstop_ms, duration_ms)
		return
	
	var now_ms: int = Time.get_ticks_msec()
	var target_end_ms: int = now_ms + duration_ms
	
	# Extend active hitstop if already running
	_hitstop_end_time_ms = max(_hitstop_end_time_ms, target_end_ms)
	Engine.time_scale = time_scale
	_is_hitstop_active = true
	set_process(true)

func _process(_delta: float) -> void:
	# If tree paused, hitstop does not advance
	if get_tree() and get_tree().paused:
		return
	
	if not _is_hitstop_active:
		set_process(false)
		return
	
	if Time.get_ticks_msec() >= _hitstop_end_time_ms:
		Engine.time_scale = 1.0
		_is_hitstop_active = false
		_hitstop_end_time_ms = 0
		set_process(false)

func _on_pause_toggled(is_paused: bool) -> void:
	if is_paused:
		if _is_hitstop_active:
			_remaining_hitstop_ms = max(0, _hitstop_end_time_ms - Time.get_ticks_msec())
			_is_hitstop_active = false
			_hitstop_end_time_ms = 0
		# Always restore time_scale to 1.0 while paused so menus and UI tick normally
		Engine.time_scale = 1.0
	else:
		if _remaining_hitstop_ms > 0:
			Engine.time_scale = _active_hitstop_scale
			_hitstop_end_time_ms = Time.get_ticks_msec() + _remaining_hitstop_ms
			_remaining_hitstop_ms = 0
			_is_hitstop_active = true
			set_process(true)
		else:
			Engine.time_scale = 1.0

func reset_time_scale() -> void:
	_is_hitstop_active = false
	_hitstop_end_time_ms = 0
	_remaining_hitstop_ms = 0
	Engine.time_scale = 1.0
	set_process(false)
