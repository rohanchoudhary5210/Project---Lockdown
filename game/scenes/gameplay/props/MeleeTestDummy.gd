class_name MeleeTestDummy
extends StaticBody3D

## Project: Lockdown - Melee Sparring Test Dummy
## Uses shared EnemyMeleeTelegraphComponent to demonstrate enemy melee telegraph (0.4s wind-up)
## and reactions to player melee attacks (35 dmg), blocks (-70% dmg), and parry stuns (1.5s).

signal attack_telegraphed()
signal attack_executed()
signal stunned(duration: float)

@onready var health_component: HealthComponent = $HealthComponent
@onready var telegraph_component: EnemyMeleeTelegraphComponent = $EnemyMeleeTelegraphComponent
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var is_stunned: bool:
	get:
		return telegraph_component.is_stunned if telegraph_component else false

var is_telegraphing: bool:
	get:
		return telegraph_component.is_telegraphing if telegraph_component else false

var _normal_mat: StandardMaterial3D = null
var _telegraph_mat: StandardMaterial3D = null
var _stun_mat: StandardMaterial3D = null

func _ready() -> void:
	if mesh_instance and mesh_instance.get_active_material(0):
		_normal_mat = mesh_instance.get_active_material(0).duplicate()
		
		_telegraph_mat = _normal_mat.duplicate()
		_telegraph_mat.albedo_color = Color(1.0, 0.6, 0.1) # Glowing amber telegraph
		_telegraph_mat.emission_enabled = true
		_telegraph_mat.emission = Color(0.9, 0.4, 0.0)
		
		_stun_mat = _normal_mat.duplicate()
		_stun_mat.albedo_color = Color(0.2, 0.6, 1.0) # Electric blue stunned
		_stun_mat.emission_enabled = true
		_stun_mat.emission = Color(0.1, 0.4, 0.9)
	
	if telegraph_component:
		telegraph_component.attack_telegraphed.connect(_on_telegraph_started)
		telegraph_component.attack_executed.connect(_on_attack_executed)
		telegraph_component.stunned.connect(_on_stunned)
		telegraph_component.stun_recovered.connect(_on_stun_recovered)
	
	if health_component:
		health_component.died.connect(_on_died)

func _on_telegraph_started() -> void:
	attack_telegraphed.emit()
	if mesh_instance and _telegraph_mat:
		mesh_instance.set_surface_override_material(0, _telegraph_mat)

func _on_attack_executed() -> void:
	attack_executed.emit()
	if mesh_instance:
		mesh_instance.set_surface_override_material(0, null)

func _on_stunned(duration: float) -> void:
	stunned.emit(duration)
	if mesh_instance and _stun_mat:
		mesh_instance.set_surface_override_material(0, _stun_mat)

func _on_stun_recovered() -> void:
	if mesh_instance:
		mesh_instance.set_surface_override_material(0, null)

func apply_stun(duration: float = 1.5) -> void:
	if telegraph_component:
		telegraph_component.apply_stun(duration)

func trigger_telegraphed_attack(target_node: Node) -> void:
	if telegraph_component:
		telegraph_component.trigger_telegraphed_attack(target_node)

func take_damage(amount: float, source: Node = null, _damage_type: String = "melee") -> void:
	if health_component:
		health_component.take_damage(amount, source)
		_flash_damage()

func _flash_damage() -> void:
	if is_stunned:
		return
	if mesh_instance:
		var flash = _normal_mat.duplicate()
		flash.albedo_color = Color(1.0, 0.2, 0.2)
		mesh_instance.set_surface_override_material(0, flash)
		await get_tree().create_timer(0.08, true, false, true).timeout
		if mesh_instance and not is_stunned and not is_telegraphing:
			mesh_instance.set_surface_override_material(0, null)

func _on_died() -> void:
	await get_tree().create_timer(0.8, true, false, true).timeout
	if health_component:
		health_component.reset_health()
	if mesh_instance:
		mesh_instance.set_surface_override_material(0, null)
