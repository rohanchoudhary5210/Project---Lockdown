class_name EncounterZone
extends Node3D

## Project: Lockdown - Encounter Zone (Milestone 6)
## Groups enemies and pickups for tactical encounter management and checkpoint rollback.
## Rule:
## - Entities killed/looted BEFORE the checkpoint stay dead/looted.
## - Entities killed/looted AFTER the checkpoint are restored on respawn.

@export var zone_id: String = ""
@export var enemies: Array[EnemyBase] = []
@export var pickups: Array[CollisionObject3D] = []

class EnemyRecord:
	var enemy: EnemyBase
	var initial_transform: Transform3D
	var committed_dead: bool = false

class PickupRecord:
	var pickup: CollisionObject3D
	var committed_looted: bool = false

var _enemy_records: Array[EnemyRecord] = []
var _pickup_records: Array[PickupRecord] = []

func _ready() -> void:
	if zone_id.is_empty():
		zone_id = name
	
	add_to_group("encounter_zones")
	call_deferred("_discover_and_register_entities")

func _discover_and_register_entities() -> void:
	# If enemies array not explicitly populated in inspector, discover from descendants
	if enemies.is_empty():
		for child in find_children("*", "EnemyBase", true, false):
			if child is EnemyBase and child not in enemies:
				enemies.append(child)
	
	# If pickups array not explicitly populated, discover from descendants
	if pickups.is_empty():
		for child in find_children("*", "CollisionObject3D", true, false):
			if child.has_method("reset_pickup") and child not in pickups:
				pickups.append(child)
	
	_enemy_records.clear()
	for e in enemies:
		if is_instance_valid(e):
			var rec = EnemyRecord.new()
			rec.enemy = e
			rec.initial_transform = e.global_transform
			rec.committed_dead = false
			_enemy_records.append(rec)
	
	_pickup_records.clear()
	for p in pickups:
		if is_instance_valid(p):
			var rec = PickupRecord.new()
			rec.pickup = p
			rec.committed_looted = false
			_pickup_records.append(rec)

## Commits current state of all entities at the moment a checkpoint is activated
func commit_checkpoint() -> void:
	for rec in _enemy_records:
		if is_instance_valid(rec.enemy):
			var is_dead: bool = (rec.enemy.current_state == EnemyBase.State.DEAD)
			if rec.enemy.health_component and rec.enemy.health_component.is_dead:
				is_dead = true
			rec.committed_dead = is_dead
	
	for rec in _pickup_records:
		if is_instance_valid(rec.pickup):
			var is_looted: bool = false
			if "is_looted" in rec.pickup:
				is_looted = rec.pickup.is_looted
			rec.committed_looted = is_looted

## Resets any changes that occurred AFTER the latest checkpoint
func reset_to_checkpoint() -> void:
	for rec in _enemy_records:
		if not is_instance_valid(rec.enemy):
			continue
		
		if rec.committed_dead:
			# Stayed dead from before this checkpoint
			rec.enemy.current_state = EnemyBase.State.DEAD
			rec.enemy.collision_layer = 0
			rec.enemy.collision_mask = 0
			rec.enemy.velocity = Vector3.ZERO
		else:
			# Was alive at checkpoint; restore to spawn, full health, PATROL state
			rec.enemy.reset_to_spawn(rec.initial_transform)
	
	for rec in _pickup_records:
		if not is_instance_valid(rec.pickup):
			continue
		
		if rec.committed_looted:
			# Stayed looted from before this checkpoint
			if "is_looted" in rec.pickup:
				rec.pickup.is_looted = true
			if rec.pickup.has_node("InteractableComponent"):
				var ic = rec.pickup.get_node("InteractableComponent")
				ic.is_interactable = false
			rec.pickup.visible = false
			rec.pickup.collision_layer = 0
		else:
			# Was unlooted at checkpoint; restore
			if rec.pickup.has_method("reset_pickup"):
				rec.pickup.reset_pickup()
