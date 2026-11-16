class_name LevelExitTrigger
extends Area3D

## Project: Lockdown - Level Exit Trigger (Milestone 8)
## Placed at the top of Stair B.
## Triggers LevelClearScreen with elapsed time and captive rescue status.

@export var level_clear_screen_scene: PackedScene = preload("res://game/scenes/ui/mfw/LevelClearScreen.tscn")

var _start_time: float = 0.0
var _cleared: bool = false
var _screen_instance: CanvasLayer = null

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Player body is on physics layer 2
	body_entered.connect(_on_body_entered)
	_start_time = Time.get_ticks_msec() / 1000.0

func _exit_tree() -> void:
	if is_instance_valid(_screen_instance):
		_screen_instance.queue_free()
		_screen_instance = null

func _on_body_entered(body: Node3D) -> void:
	if _cleared:
		return
	if not body.is_in_group("player"):
		return
	
	_cleared = true
	trigger_clear()

func trigger_clear() -> void:
	var elapsed: float = (Time.get_ticks_msec() / 1000.0) - _start_time
	
	# Check whether Officer Walker / captives are rescued
	var rescued: bool = false
	var captives = get_tree().get_nodes_in_group("captives")
	for c in captives:
		if "is_rescued" in c and c.is_rescued:
			rescued = true
			break
	
	var im = get_node_or_null("/root/InputManager")
	if im:
		im.is_level_clear_active = true
		im.mouse_captured = false
	
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	if not _screen_instance and level_clear_screen_scene:
		_screen_instance = level_clear_screen_scene.instantiate() as CanvasLayer
		get_tree().root.add_child(_screen_instance)
	
	if _screen_instance and _screen_instance.has_method("show_screen"):
		_screen_instance.show_screen(elapsed, rescued)
