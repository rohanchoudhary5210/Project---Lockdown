class_name TestServices
extends RefCounted

## Test scripts run as a bare SceneTree, without Boot.tscn: start GameService so the game's services
## exist and every node added afterwards gets inject_services(), exactly as in the real game.

static func start(tree: SceneTree) -> void:
	if tree.root.has_node("GameService"):
		return
	var game_service: Node = load("res://game/autoloads/GameService.gd").new()
	game_service.name = "GameService"
	tree.root.add_child(game_service)
	await tree.process_frame

static func get_service(tree: SceneTree, key: StringName) -> Node:
	return tree.root.get_node("ServiceRegistry").get_service(key)
