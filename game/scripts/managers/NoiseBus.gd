class_name NoiseBus
extends Node

## Project: Lockdown - NoiseBus Autoload
## Central acoustic bus connecting sound sources (player footsteps, gunshots, impacts)
## to acoustic sensors on hostile AI perception components.

signal noise_emitted(position: Vector3, radius: float, source: Node, noise_type: String)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

## Broadcasts an acoustic event in 3D world space
func emit_noise(pos: Vector3, radius: float, source: Node = null, noise_type: String = "generic") -> void:
	if radius <= 0.0:
		return
	noise_emitted.emit(pos, radius, source, noise_type)
