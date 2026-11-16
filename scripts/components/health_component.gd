class_name HealthComponent
extends Node

## Project: Lockdown - Health Component
## Reusable combat component for Player, Enemies, and damageable entities.
## Emits signals for health updates, damage reactions, and death handling.

signal health_changed(current: float, max_health: float)
signal damaged(amount: float, source: Node)
signal healed(amount: float)
signal died()

@export var max_health: float = 100.0
@export var invulnerable: bool = false

var current_health: float = 100.0
var is_dead: bool = false

func _ready() -> void:
	current_health = max_health
	call_deferred("_emit_initial_health")

func _emit_initial_health() -> void:
	health_changed.emit(current_health, max_health)

func take_damage(amount: float, source: Node = null) -> void:
	if is_dead or invulnerable or amount <= 0.0:
		return
	
	current_health = max(current_health - amount, 0.0)
	damaged.emit(amount, source)
	health_changed.emit(current_health, max_health)
	
	if current_health <= 0.0:
		is_dead = true
		died.emit()

func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	
	current_health = min(current_health + amount, max_health)
	healed.emit(amount)
	health_changed.emit(current_health, max_health)

func reset_health(new_max: float = -1.0) -> void:
	if new_max > 0.0:
		max_health = new_max
	current_health = max_health
	is_dead = false
	health_changed.emit(current_health, max_health)

## The node that takes damage for a hit collider: the collider itself or its parent (hitbox case).
static func find_damageable(collider: Node) -> Node:
	if collider == null:
		return null
	if collider.has_method("take_damage"):
		return collider
	var parent := collider.get_parent()
	if parent and parent.has_method("take_damage"):
		return parent
	return null

## True if the node has a HealthComponent that reports it dead.
static func is_node_dead(node: Node) -> bool:
	var hc = node.get("health_component") if node else null
	return hc != null and hc.is_dead

func get_health_ratio() -> float:
	return current_health / max_health if max_health > 0.0 else 0.0
