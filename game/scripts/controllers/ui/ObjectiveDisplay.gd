class_name ObjectiveDisplay
extends Label

## Project: Lockdown - Objective Display
## Top-center objective text. Built from what the level contains: a LevelExitTrigger gives the main
## objective, unrescued captives add an optional one. Shown for a few seconds when it changes,
## at level start and after respawn, and always while paused. Levels without an exit show nothing.

@export var show_duration: float = 5.0
@export var fade_duration: float = 0.6

var _show_timer: float = 0.0
var _paused: bool = false

## Services come from GameService (see GameService._inject_into_new_nodes); null when run without it.
var _checkpoints: CheckpointManager
var _input_manager: InputManager

func inject_services(registry: Node) -> void:
	_checkpoints = registry.get_service(&"checkpoint") as CheckpointManager
	_input_manager = registry.get_service(&"input") as InputManager

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	set_anchors_preset(PRESET_CENTER_TOP)
	grow_horizontal = GROW_DIRECTION_BOTH
	offset_left = -320.0
	offset_right = 320.0
	# Below the "Checkpoint reached" banner (y 60-105), which often shows at the same time at level start
	offset_top = 114.0
	offset_bottom = 164.0
	add_theme_font_size_override("font_size", 18)
	add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
	add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	add_theme_constant_override("outline_size", 4)
	modulate.a = 0.0
	call_deferred("_connect_level")

func _connect_level() -> void:
	for c in get_tree().get_nodes_in_group("captives"):
		if c.has_signal("rescued") and not c.rescued.is_connected(_on_changed):
			c.rescued.connect(_on_changed)
	var cm = _checkpoints
	if cm and cm.has_signal("player_respawned") and not cm.player_respawned.is_connected(_on_changed):
		cm.player_respawned.connect(_on_changed)
	var im = _input_manager
	if im and im.has_signal("pause_toggled") and not im.pause_toggled.is_connected(_on_pause_toggled):
		im.pause_toggled.connect(_on_pause_toggled)
	refresh()

## Objective text for the current level state ("" when the level has no exit).
func build_text() -> String:
	var scene := get_tree().current_scene
	if scene == null or scene.find_children("*", "LevelExitTrigger", true, false).is_empty():
		return ""
	var lines: PackedStringArray = ["Reach the stairwell exit (Stair B)"]
	for c in get_tree().get_nodes_in_group("captives"):
		if not c.get("is_rescued"):
			lines.append("Optional: find and rescue the captured officer")
			break
	return "\n".join(lines)

func refresh() -> void:
	text = build_text()
	_show_timer = show_duration if text != "" else 0.0

func _on_changed(_arg = null) -> void:
	call_deferred("refresh") # after respawn rollback / rescue state has settled

func _on_pause_toggled(is_paused: bool) -> void:
	_paused = is_paused

func _process(delta: float) -> void:
	if _show_timer > 0.0:
		_show_timer -= delta
	var target: float = 1.0 if text != "" and (_paused or _show_timer > 0.0) else 0.0
	if _show_timer > 0.0 and _show_timer < fade_duration and not _paused:
		target = _show_timer / fade_duration
	modulate.a = move_toward(modulate.a, target, delta / fade_duration)
