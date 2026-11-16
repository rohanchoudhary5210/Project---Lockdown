class_name FlickeringLight
extends OmniLight3D

## Atmospheric flickering ceiling light for corridor ambience.

@export var base_energy: float = 0.85
@export var min_energy: float = 0.15
@export var max_energy: float = 1.05

var _timer: float = 0.0

func _ready() -> void:
	light_energy = base_energy

func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(0.04, 0.18)
		if randf() < 0.22:
			light_energy = randf_range(min_energy, base_energy * 0.5)
		else:
			light_energy = randf_range(base_energy * 0.8, max_energy)
