class_name ServiceBootstrap
extends RefCounted

## Scenes started without Boot.tscn (editor "Run Current Scene", test scripts) have no GameService.
## Call ensure() from the scene root's _enter_tree(): GameService becomes its first child, so it is
## ready before any sibling and injects services into the whole scene before their _ready().
static func ensure(scene_root: Node) -> void:
	var registry: Node = scene_root.get_tree().root.get_node_or_null("ServiceRegistry")
	if registry == null or registry.has_service(&"game"):
		return
	if scene_root.get_tree().root.has_node("GameService") or scene_root.has_node("GameService"):
		return
	var game_service: Node = load("res://game/autoloads/GameService.gd").new()
	game_service.name = "GameService"
	scene_root.add_child(game_service)
	scene_root.move_child(game_service, 0)
