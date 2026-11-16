class_name Flashlight
extends SpotLight3D

## Project: Lockdown - Flashlight
## Hand torch on the player camera. Limited battery that drains while it is on; below 20% it starts
## to stutter, at 0 it dies. Battery pickups recharge it. Being lit makes the player easier to spot
## (Player.get_light_exposure()), so turning it off is a real choice.

signal toggled_light(on: bool)
signal battery_changed(ratio: float)

@export var battery_capacity: float = 240.0 ## Seconds of light on a full battery
@export var low_battery_ratio: float = 0.2
@export var on_energy: float = 2.4

var battery: float = 0.0
var is_on: bool = false

var _flicker_timer: float = 0.0
var _dropout: float = 0.0
var _spatial_audio: SpatialAudioManager
var _click: AudioStream = preload("res://game/assets/audio/procedural/sfx_flashlight_click.tres")

func inject_services(registry: Node) -> void:
	_spatial_audio = registry.get_service(&"spatial_audio") as SpatialAudioManager

func _ready() -> void:
	battery = battery_capacity
	visible = false
	light_energy = on_energy
	call_deferred("_emit_battery")

func _emit_battery() -> void:
	battery_changed.emit(get_battery_ratio())

func get_battery_ratio() -> float:
	return clampf(battery / battery_capacity, 0.0, 1.0)

## True when the beam is actually lighting things (on, charged, not in a flicker dropout).
func is_lit() -> bool:
	return is_on and visible

func toggle() -> void:
	set_on(not is_on)

func set_on(on: bool) -> void:
	if _spatial_audio:
		_spatial_audio.play_sfx(_click, 0.08, -6.0)
	if on and battery <= 0.0:
		return # dead battery: just the click
	is_on = on
	visible = on
	toggled_light.emit(on)

## Adds charge (seconds of light). Returns how much was actually added.
func add_battery(seconds: float) -> float:
	var added := minf(seconds, battery_capacity - battery)
	battery += added
	battery_changed.emit(get_battery_ratio())
	return added

func _process(delta: float) -> void:
	if not is_on:
		return
	var before := get_battery_ratio()
	battery = maxf(battery - delta, 0.0)
	if int(before * 100.0) != int(get_battery_ratio() * 100.0):
		battery_changed.emit(get_battery_ratio())
	if battery <= 0.0:
		is_on = false
		visible = false
		toggled_light.emit(false)
		return
	# Weak battery: dimmer beam with short random dropouts
	var ratio := get_battery_ratio()
	if ratio < low_battery_ratio:
		_flicker_timer -= delta
		if _dropout > 0.0:
			_dropout -= delta
			visible = _dropout <= 0.0
		elif _flicker_timer <= 0.0:
			_flicker_timer = randf_range(0.6, 3.0) * (0.5 + ratio / low_battery_ratio)
			_dropout = randf_range(0.04, 0.25)
			visible = false
		light_energy = on_energy * lerpf(0.45, 1.0, ratio / low_battery_ratio)
	else:
		visible = true
		light_energy = on_energy
