class_name DeathScreen
extends UIController

## Project: Lockdown - Death Screen
## "YOU DIED" panel. The HUD pushes it on CheckpointManager.death_screen_shown; restarting respawns
## at the last checkpoint and closes it. Input is ignored for the first 0.5s, and a key that was
## already held when it appeared must be released first, so a held jump/interact can't skip it.

const INPUT_DELAY: float = 0.5

@onready var restart_button: Button = %RestartButton
@onready var hint_label: Label = %Hint

var _input_ready: bool = false
var _key_must_release: bool = false

## Services come from GameService (see GameService._inject_into_new_nodes); null when run without it.
var _checkpoints: CheckpointManager
var _input_manager: InputManager

func inject_services(registry: Node) -> void:
	super.inject_services(registry)
	_checkpoints = registry.get_service(&"checkpoint") as CheckpointManager
	_input_manager = registry.get_service(&"input") as InputManager

func _on_ready() -> void:
	restart_button.pressed.connect(_on_restart_pressed)
	restart_button.disabled = true
	_key_must_release = Input.is_action_pressed("interact") or Input.is_action_pressed("jump")
	var im = _input_manager
	var interact_key = im.get_action_key_label("interact") if im else "E"
	var jump_key = im.get_action_key_label("jump") if im else "Space"
	hint_label.text = "Press [%s] or [%s] to restart" % [interact_key, jump_key]

	await get_tree().create_timer(INPUT_DELAY, true, false, true).timeout
	if is_inside_tree():
		_input_ready = true
		restart_button.disabled = false
		restart_button.grab_focus()

func is_input_ready() -> bool:
	return _input_ready

func _unhandled_input(event: InputEvent) -> void:
	if _key_must_release:
		if not Input.is_action_pressed("interact") and not Input.is_action_pressed("jump"):
			_key_must_release = false
		return
	if not _input_ready:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("jump"):
		if not event.is_echo():
			_on_restart_pressed()
			get_viewport().set_input_as_handled()

func _on_restart_pressed() -> void:
	if not _input_ready:
		return
	_input_ready = false
	close()
	var cm = _checkpoints
	if cm and cm.has_method("respawn_player"):
		cm.respawn_player()
