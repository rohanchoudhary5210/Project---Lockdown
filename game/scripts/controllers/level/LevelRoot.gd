class_name LevelRoot
extends Node3D

## Root of every level scene. Only job: make the level runnable on its own (F6) without Boot.tscn.

func _enter_tree() -> void:
	ServiceBootstrap.ensure(self)
