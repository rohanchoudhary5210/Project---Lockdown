class_name Medkit
extends StaticBody3D

@onready var interactable: InteractableComponent = $InteractableComponent
var is_looted: bool = false
const HEAL_AMOUNT: float = 35.0

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
	if player and player.health_component:
		if player.health_component.current_health >= player.health_component.max_health:
			return "Health Full"
	var im = _input_manager
	var key = im.get_action_key_label("interact") if im else "E"
	return "[%s] Pick Up Medkit (+%d HP)" % [key, int(HEAL_AMOUNT)]

func interact(interactor: Node) -> void:
	if is_looted:
		return
	if interactor.has_method("heal") and interactor.health_component:
		if interactor.health_component.current_health >= interactor.health_component.max_health:
			return # Do not consume if health is already full!
		interactor.heal(HEAL_AMOUNT)
		is_looted = true
		var am = _spatial_audio
		if am and am.has_method("play_pickup"):
			am.play_pickup()
		visible = false
		collision_layer = 0
		if interactable:
			interactable.is_interactable = false

func reset_pickup() -> void:
	is_looted = false
	visible = true
	collision_layer = 8
	if interactable:
		interactable.is_interactable = true
