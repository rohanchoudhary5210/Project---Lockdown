class_name LevelExitTrigger
extends Area3D

## Project: Lockdown - Level Exit Trigger (Milestone 8)
## Placed at the top of Stair B.
## Triggers LevelClearScreen with elapsed time and captive rescue status.

@export var level_clear_screen_scene: PackedScene = preload("res://game/scenes/ui/mfw/LevelClearScreen.tscn")
## Main objective line shown by the HUD's ObjectiveDisplay.
@export var objective_text: String = "Reach the stairwell exit (Stair B)"
## Level to load when the player reaches this exit. Empty: this is the last level, show the clear screen.
@export_file("*.tscn") var next_level: String = ""

var _start_time: float = 0.0
var _cleared: bool = false
var _screen_instance: LevelClearScreen = null

## Services come from GameService (see GameService._inject_into_new_nodes); null when run without it.
var _input_manager: InputManager
var _ui: UIManager
var _game: GameManager
var _bus: Node
var _scene: SceneManager
var _checkpoints: CheckpointManager

func inject_services(registry: Node) -> void:
	_scene = registry.get_service(&"scene") as SceneManager
	_checkpoints = registry.get_service(&"checkpoint") as CheckpointManager
	_ui = registry.get_service(&"ui") as UIManager
	_game = registry.get_service(&"game") as GameManager
	_bus = registry.get_service(&"bus")
	_input_manager = registry.get_service(&"input") as InputManager

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Player body is on physics layer 2
	body_entered.connect(_on_body_entered)
	_start_time = Time.get_ticks_msec() / 1000.0

func _exit_tree() -> void:
	# Leaving the level with the panel still open (not via its Restart): take it off the UI stack
	if is_instance_valid(_screen_instance) and _ui and _ui.current() == _screen_instance:
		_ui.pop()
	_screen_instance = null

func _on_body_entered(body: Node3D) -> void:
	if _cleared:
		return
	if not body.is_in_group("player"):
		return
	
	_cleared = true
	if next_level != "":
		go_to_next_level()
	else:
		trigger_clear()

## Mid-run exit: straight into the next level, which starts its own checkpoint session.
func go_to_next_level() -> void:
	if _bus:
		_bus.level_completed.emit(String(get_tree().current_scene.name) if get_tree().current_scene else "")
	if _checkpoints:
		_checkpoints.reset_session()
	_scene.go_to(next_level)

func trigger_clear() -> void:
	var elapsed: float = (Time.get_ticks_msec() / 1000.0) - _start_time
	
	# Check whether Officer Walker / captives are rescued
	var rescued: bool = false
	var captives = get_tree().get_nodes_in_group("captives")
	for c in captives:
		if "is_rescued" in c and c.is_rescued:
			rescued = true
			break
	
	var im = _input_manager
	if im:
		im.is_level_clear_active = true
		im.mouse_captured = false
	
	if _game:
		_game.pause()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _bus:
		_bus.level_completed.emit(String(get_tree().current_scene.name) if get_tree().current_scene else "")
	
	if not _screen_instance and level_clear_screen_scene:
		_ui.push_packed(level_clear_screen_scene)
		_screen_instance = _ui.current() as LevelClearScreen
	
	if _screen_instance and _screen_instance.has_method("show_screen"):
		_screen_instance.show_screen(elapsed, rescued)
