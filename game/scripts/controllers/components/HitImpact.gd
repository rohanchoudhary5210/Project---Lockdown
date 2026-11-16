class_name HitImpact
extends Node3D

func _ready() -> void:
	await get_tree().create_timer(0.25, true, false, true).timeout
	queue_free()
