class_name LevelRoot
extends Node3D

## Root of every level scene: starts the GameManager session for the level, and makes the level
## runnable on its own (F6) without Boot.tscn.

var _game: GameManager
var _bus: Node

func inject_services(registry: Node) -> void:
	_game = registry.get_service(&"game") as GameManager
	_bus = registry.get_service(&"bus")

func _enter_tree() -> void:
	ServiceBootstrap.ensure(self)

func _ready() -> void:
	if _game:
		_game.reset()
		_game.start()
	if _bus:
		_bus.level_started.emit(String(name))
