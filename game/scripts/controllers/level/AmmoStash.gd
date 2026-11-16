class_name AmmoStash
extends StaticBody3D

@onready var interactable: InteractableComponent = $InteractableComponent
var is_looted: bool = false
const AMMO_AMOUNT: int = 24

## Services come from GameService (see GameService._inject_into_new_nodes); null when run without it.
var _input_manager: InputManager
var _spatial_audio: SpatialAudioManager

func inject_services(registry: Node) -> void:
	_input_manager = registry.get_service(&"input") as InputManager
	_spatial_audio = registry.get_service(&"spatial_audio") as SpatialAudioManager

func get_prompt() -> String:
	if is_looted:
		return ""
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var weapon = player.find_child("Pistol", true, false)
		if weapon and not weapon.can_add_reserve_ammo():
			return "Ammo Full"
	var im = _input_manager
	var key = im.get_action_key_label("interact") if im else "E"
	return "[%s] Take Ammunition (+%d)" % [key, AMMO_AMOUNT]

func interact(interactor: Node) -> void:
	if is_looted:
		return
	var weapon = interactor.find_child("Pistol", true, false)
	if weapon:
		if not weapon.can_add_reserve_ammo():
			return
		var added = weapon.add_reserve_ammo(AMMO_AMOUNT)
		if added > 0:
			is_looted = true
			var am = _spatial_audio
			if am and am.has_method("play_pickup"):
				am.play_pickup()
			if interactable:
				interactable.is_interactable = false

func reset_pickup() -> void:
	is_looted = false
	visible = true
	collision_layer = 8
	if interactable:
		interactable.is_interactable = true
