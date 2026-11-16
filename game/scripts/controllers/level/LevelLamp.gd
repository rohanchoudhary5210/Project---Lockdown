class_name LevelLamp
extends Node3D

## Project: Lockdown - Level Lamp
## A ceiling lamp (fixture mesh + "Light" child). Lamps can be unpowered in the editor or switched off
## by events (LightsOutEvent), and tell the AI how lit a spot is (see Player.get_light_exposure()).

signal power_changed(powered: bool)

@export var powered: bool = true:
	set(v):
		powered = v
		if is_node_ready():
			_apply_power()

@onready var light: OmniLight3D = get_node_or_null("Light") as OmniLight3D
@onready var fixture: MeshInstance3D = get_node_or_null("Fixture") as MeshInstance3D

var _powered_at_start: bool = true
var _off_material: StandardMaterial3D

func _ready() -> void:
	add_to_group("level_lamps")
	_powered_at_start = powered
	_off_material = StandardMaterial3D.new()
	_off_material.albedo_color = Color(0.12, 0.12, 0.12)
	_apply_power()

func _apply_power() -> void:
	if light:
		light.visible = powered
		light.set_process(powered) # FlickeringLight stops ticking when the power is gone
	if fixture:
		fixture.material_override = null if powered else _off_material
	power_changed.emit(powered)

func set_powered(on: bool) -> void:
	powered = on

## Back to the editor state (checkpoint rollback of a LightsOutEvent).
func restore_power() -> void:
	powered = _powered_at_start

## 0..1: how strongly this lamp lights a point (linear falloff over its range, wall occlusion ignored).
func light_strength_at(point: Vector3) -> float:
	if not powered or light == null:
		return 0.0
	var d := light.global_position.distance_to(point)
	if d >= light.omni_range:
		return 0.0
	return clampf(light.light_energy, 0.0, 1.5) / 1.5 * (1.0 - d / light.omni_range) * 1.4
