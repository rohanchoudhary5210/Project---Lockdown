class_name ShootingTarget
extends StaticBody3D

## Project: Lockdown - Shooting Target Dummy
## Uses HealthComponent for damage tracking and triggers visual flash and reset.

signal damage_taken(current_hp: float, max_hp: float)

@onready var health_component: HealthComponent = $HealthComponent
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var _orig_material: StandardMaterial3D = null
var _flash_material: StandardMaterial3D = null

func _ready() -> void:
	if mesh_instance and mesh_instance.get_active_material(0):
		_orig_material = mesh_instance.get_active_material(0).duplicate()
		_flash_material = _orig_material.duplicate()
		_flash_material.albedo_color = Color(1.0, 0.2, 0.2, 1.0)
		_flash_material.emission_enabled = true
		_flash_material.emission = Color(0.8, 0.1, 0.1, 1.0)
	
	if health_component:
		health_component.damaged.connect(_on_damaged)
		health_component.died.connect(_on_died)
		health_component.health_changed.connect(func(c, m): damage_taken.emit(c, m))

func take_damage(amount: float, source: Node = null, _damage_type: String = "bullet") -> void:
	if health_component:
		health_component.take_damage(amount, source)

func _on_damaged(_amount: float, _source: Node) -> void:
	_flash_hit()

func _on_died() -> void:
	_reset_target()

func _flash_hit() -> void:
	if mesh_instance and _flash_material:
		mesh_instance.set_surface_override_material(0, _flash_material)
		await get_tree().create_timer(0.08, true, false, true).timeout
		if mesh_instance:
			mesh_instance.set_surface_override_material(0, null)

func _reset_target() -> void:
	await get_tree().create_timer(0.8, true, false, true).timeout
	if health_component:
		health_component.reset_health()
