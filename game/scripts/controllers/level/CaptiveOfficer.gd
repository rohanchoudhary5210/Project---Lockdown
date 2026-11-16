class_name CaptiveOfficer
extends StaticBody3D

## Project: Lockdown - Captive Teammate Officer (Milestone 7)
## Placeholder kneeling officer in police blue.
## Held for 2s to rescue. Rewards +24 ammo and +35 HP, triggers dialogue.
## Non-damageable, does not fight or follow yet.
## Rescued state preserved across checkpoints.

signal rescued(officer: CaptiveOfficer)

@export var captive_id: String = "Captive_Officer1"
@export var officer_name: String = "Officer Walker"
@export var is_hold_interaction: bool = true
@export var hold_duration: float = 2.0
## What the officer says after the rescue (one subtitle per line, 3.5s each).
@export var rescue_lines: PackedStringArray = [
	"Good to see you, officer. The stairwell to the next floor is watched by two shooters.",
	"Take my spare rounds and patch up. Watch your corners.",
]

@onready var interactable: InteractableComponent = $InteractableComponent
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var vest_mesh: MeshInstance3D = $VestMesh

var is_rescued: bool = false
var _kneeling_mat: StandardMaterial3D = null
var _rescued_mat: StandardMaterial3D = null

## Services come from GameService (see GameService._inject_into_new_nodes); null when run without it.
var _input_manager: InputManager
var _spatial_audio: SpatialAudioManager
var _subtitles: SubtitleManager

func inject_services(registry: Node) -> void:
	_input_manager = registry.get_service(&"input") as InputManager
	_spatial_audio = registry.get_service(&"spatial_audio") as SpatialAudioManager
	_subtitles = registry.get_service(&"subtitle") as SubtitleManager

func _ready() -> void:
	if captive_id.is_empty():
		captive_id = name
	
	add_to_group("captives")
	collision_layer = 8 # Layer 4 named interactables
	collision_mask = 0
	
	_setup_materials()
	set_rescued_state(is_rescued)

func _setup_materials() -> void:
	_kneeling_mat = StandardMaterial3D.new()
	_kneeling_mat.albedo_color = Color(0.12, 0.28, 0.58) # Police Navy Blue
	_kneeling_mat.roughness = 0.6
	
	_rescued_mat = StandardMaterial3D.new()
	_rescued_mat.albedo_color = Color(0.2, 0.45, 0.8) # Relieved lighter blue
	_rescued_mat.roughness = 0.5

func get_prompt() -> String:
	if is_rescued:
		return ""
	var im = _input_manager
	var key = im.get_action_key_label("interact") if im else "E"
	return "[%s] Hold to Rescue Officer" % key

func complete_interaction(player: Node) -> void:
	if is_rescued:
		return
	
	set_rescued_state(true)
	rescued.emit(self)
	
	# 1. Reward: +24 reserve ammo (clamped to max_reserve)
	if player:
		var weapon = player.find_child("Pistol", true, false)
		if weapon and weapon.has_method("add_reserve_ammo"):
			weapon.add_reserve_ammo(24)
		
		# 2. Reward: +35 HP (clamped to max_health)
		if player.has_method("heal"):
			player.heal(35.0)
	
	var am = _spatial_audio
	if am and am.has_method("play_pickup"):
		am.play_pickup()
	
	# 3. Subtitles: play 2 intel dialogue lines via SubtitleManager
	var sm = _subtitles
	if sm:
		for line in rescue_lines:
			sm.play_subtitle(officer_name, line, 3.5)

func set_rescued_state(rescued_status: bool) -> void:
	is_rescued = rescued_status
	
	if mesh_instance:
		mesh_instance.material_override = _rescued_mat if is_rescued else _kneeling_mat
		if mesh_instance.mesh is CapsuleMesh:
			var capsule: CapsuleMesh = mesh_instance.mesh
			capsule.height = 1.7 if is_rescued else 1.15
			mesh_instance.position.y = (1.7 * 0.5) if is_rescued else (1.15 * 0.5)
	
	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var col_capsule: CapsuleShape3D = collision_shape.shape
		col_capsule.height = 1.7 if is_rescued else 1.15
		collision_shape.position.y = (1.7 * 0.5) if is_rescued else (1.15 * 0.5)
	
	if vest_mesh:
		vest_mesh.position.y = 1.1 if is_rescued else 0.65
	
	if interactable:
		interactable.is_interactable = not is_rescued
