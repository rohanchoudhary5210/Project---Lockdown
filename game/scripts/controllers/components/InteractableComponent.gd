class_name InteractableComponent
extends Node

## Project: Lockdown - Interactable Component
## Placed on world objects to provide interaction prompts and handle interaction events.

signal interacted(interactor: Node)

@export var prompt_text: String = "[E] Interact"
@export var is_interactable: bool = true

func interact(interactor: Node) -> void:
	if not is_interactable:
		return
	interacted.emit(interactor)

func get_prompt() -> String:
	return prompt_text if is_interactable else ""
