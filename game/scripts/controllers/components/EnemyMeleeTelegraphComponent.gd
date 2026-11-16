class_name EnemyMeleeTelegraphComponent
extends Node

## Shared Enemy Melee Telegraph & Parry/Stun Component
## Reusable across MeleeTestDummy and the Rusher enemy archetype.
## Provides a 0.4s telegraph wind-up state before delivering a melee strike,
## a stun hook that interrupts active attacks and incapacitates the entity for 1.5s,
## and a cancel hook for flinch on bullet impacts.

signal attack_telegraphed()
signal attack_executed()
signal attack_cancelled()
signal stunned(duration: float)
signal stun_recovered()

@export var attack_damage: float = 20.0
@export var telegraph_duration: float = 0.4
@export var default_stun_duration: float = 1.5

var is_telegraphing: bool = false
var is_stunned: bool = false
var _stun_timer: float = 0.0
var _attack_sequence_id: int = 0

func _process(delta: float) -> void:
	if is_stunned:
		_stun_timer = max(_stun_timer - delta, 0.0)
		if _stun_timer <= 0.0:
			_recover_from_stun()

func apply_stun(duration: float = 1.5) -> void:
	is_stunned = true
	if is_telegraphing:
		cancel_telegraph()
	_stun_timer = duration
	stunned.emit(duration)

func cancel_telegraph() -> void:
	if is_telegraphing:
		is_telegraphing = false
		_attack_sequence_id += 1
		attack_cancelled.emit()

func _recover_from_stun() -> void:
	is_stunned = false
	_stun_timer = 0.0
	stun_recovered.emit()

func trigger_telegraphed_attack(target_node: Node) -> void:
	if is_stunned or is_telegraphing:
		return
	
	is_telegraphing = true
	_attack_sequence_id += 1
	var seq_id: int = _attack_sequence_id
	attack_telegraphed.emit()
	
	# 0.4s Telegraph wind-up phase
	await get_tree().create_timer(telegraph_duration, true, false, true).timeout
	
	# If stunned or cancelled (by bullet flinch / parry), abort damage frame!
	if is_stunned or not is_telegraphing or seq_id != _attack_sequence_id:
		is_telegraphing = false
		return
	
	is_telegraphing = false
	attack_executed.emit()
	
	# Deliver melee strike at damage frame (explicitly marked as "melee" damage)
	if target_node and target_node.has_method("take_damage"):
		var parent_node: Node = get_parent()
		target_node.take_damage(attack_damage, parent_node, "melee")
