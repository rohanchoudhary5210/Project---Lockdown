class_name RangedEnemy
extends EnemyBase

## Project: Lockdown - Ranged Enemy Archetype (Milestone 5a)
## Fires 8-damage semi-automatic shots at 0.7s interval with 0.5s initial reaction delay.
## Accuracy degrades with distance and target movement.
## If line of sight is broken, moves to last known player position.
## Gunshots emit acoustic events onto NoiseBus.

signal shot_fired(target_position: Vector3)

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var muzzle: Marker3D = $Muzzle

var _fire_cooldown: float = 0.0
var _reaction_timer: float = 0.0
var _has_reaction_delayed: bool = false
var _tracer_material: StandardMaterial3D = null

func _ready() -> void:
	super._ready()
	_tracer_material = StandardMaterial3D.new()
	_tracer_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_tracer_material.albedo_color = Color(1.0, 0.8, 0.2) # Amber tracer

func _tick_attack(delta: float) -> void:
	if not perception or not perception.player_ref or not perception.has_line_of_sight:
		# Lost line of sight; switch back to chase toward last known position
		change_state(State.CHASE)
		return
	
	var player = perception.player_ref
	last_known_player_position = player.global_position
	
	# Rotate smoothly toward player
	var to_player = (player.global_position - global_position)
	to_player.y = 0.0
	if to_player.length_squared() > 0.01:
		var target_angle = atan2(-to_player.normalized().x, -to_player.normalized().z)
		rotation.y = lerp_angle(rotation.y, target_angle, 10.0 * delta)
	
	# Stop movement while aiming & firing
	velocity.x = move_toward(velocity.x, 0.0, 15.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 15.0 * delta)
	
	# Initial reaction delay before first shot after spotting player
	if not _has_reaction_delayed:
		_reaction_timer += delta
		if _reaction_timer < enemy_data.reaction_delay:
			return
		_has_reaction_delayed = true
	
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	if _fire_cooldown <= 0.0:
		_fire_at_player(player)
		_fire_cooldown = enemy_data.fire_interval

func _can_attack() -> bool:
	if perception and perception.has_line_of_sight and perception.is_player_spotted:
		var dist = global_position.distance_to(perception.last_known_player_position)
		return dist <= enemy_data.vision_range
	return false

func change_state(new_state: State) -> void:
	if new_state != State.ATTACK:
		_has_reaction_delayed = false
		_reaction_timer = 0.0
	super.change_state(new_state)

func _fire_at_player(player: CharacterBody3D) -> void:
	var shoot_origin: Vector3
	if muzzle:
		shoot_origin = muzzle.global_position
	else:
		shoot_origin = global_position + Vector3(0, 1.4, 0)
	
	var target_center: Vector3 = player.global_position + Vector3(0, 1.0, 0)
	var to_target: Vector3 = (target_center - shoot_origin)
	var distance: float = to_target.length()
	var base_dir: Vector3 = to_target.normalized()
	
	# 1. Calculate accuracy spread
	# Spread grows with distance and increases when player is moving
	var total_spread_rad: float = enemy_data.base_spread_rad + (distance * enemy_data.distance_spread_factor)
	var player_speed: float = Vector2(player.velocity.x, player.velocity.z).length()
	if player_speed > 0.5:
		total_spread_rad *= enemy_data.player_moving_spread_mult
	
	# Apply random angular deviation
	var spread_yaw: float = randf_range(-total_spread_rad, total_spread_rad)
	var spread_pitch: float = randf_range(-total_spread_rad, total_spread_rad)
	var shot_dir: Vector3 = base_dir.rotated(Vector3.UP, spread_yaw)
	var right_axis: Vector3 = base_dir.cross(Vector3.UP).normalized()
	if right_axis.length_squared() > 0.001:
		shot_dir = shot_dir.rotated(right_axis, spread_pitch)
	
	var max_shot_distance: float = 80.0
	var shot_end: Vector3 = shoot_origin + shot_dir * max_shot_distance
	
	# 2. Physics Raycast for Hit Detection
	var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(shoot_origin, shot_end)
	query.collision_mask = 1 | 2 # World (layer 1) + Player (layer 2) only; never other enemies
	query.exclude = [get_rid()]
	
	var result: Dictionary = space_state.intersect_ray(query)
	var hit_pos: Vector3 = shot_end
	if result:
		hit_pos = result.position
		var hit_collider: Node = result.collider
		if hit_collider:
			# Bullet damage is explicitly tagged "bullet" so Player block does not mitigate it!
			if hit_collider.has_method("take_damage"):
				hit_collider.take_damage(enemy_data.damage_per_shot, self, "bullet")
			elif hit_collider.get_parent() and hit_collider.get_parent().has_method("take_damage"):
				hit_collider.get_parent().take_damage(enemy_data.damage_per_shot, self, "bullet")
	
	# 3. Spawn Visual Bullet Tracer Line
	_spawn_tracer(shoot_origin, hit_pos)
	
	# 4. Broadcast acoustic noise to NoiseBus so other enemies hear gunshots
	var nb = get_node_or_null("/root/NoiseBus")
	if nb:
		nb.emit_noise(global_position, enemy_data.gunshot_noise_radius, self, "gunshot")
	
	var am = get_node_or_null("/root/SpatialAudio")
	if am and am.has_method("play_rifle_shot"):
		am.play_rifle_shot(shoot_origin)
	
	shot_fired.emit(hit_pos)

func reset_to_spawn(spawn_transform: Transform3D) -> void:
	_fire_cooldown = 0.0
	_reaction_timer = 0.0
	_has_reaction_delayed = false
	super.reset_to_spawn(spawn_transform)

func _spawn_tracer(from_pos: Vector3, to_pos: Vector3) -> void:
	var mesh_inst := MeshInstance3D.new()
	var immediate := ImmediateMesh.new()
	immediate.surface_begin(Mesh.PRIMITIVE_LINES)
	immediate.surface_add_vertex(from_pos)
	immediate.surface_add_vertex(to_pos)
	immediate.surface_end()
	
	mesh_inst.mesh = immediate
	mesh_inst.material_override = _tracer_material
	get_tree().root.add_child(mesh_inst)
	
	# Auto-destroy tracer after brief flash (0.04s)
	await get_tree().create_timer(0.04, true, false, true).timeout
	if is_instance_valid(mesh_inst):
		mesh_inst.queue_free()
