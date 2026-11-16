extends Node

# GameService — composition root for core game services.
# It owns construction and registration; gameplay features receive dependencies
# explicitly instead of looking them up through this node.

var registry: Node

# ── Core Singletons ────────────────────────────────────────────────────────
var config: Node
var logger: Node
var bus: Node

# ── Managers ───────────────────────────────────────────────────────────────
var audio: AudioManager
var game: GameManager
var haptics: HapticsManager
var network: NetworkManager
var save: SaveManager
var scene: SceneManager
var ui: UIManager

func _ready() -> void:
	# Persist composition root across scene transitions
	if get_parent() != get_tree().root:
		reparent.call_deferred(get_tree().root)

	registry = get_tree().root.get_node_or_null("ServiceRegistry")
	if registry == null:
		push_error("GameService: ServiceRegistry autoload is required")
		return

	# 1. Initialize core singletons and data backend under composition root
	config = _instantiate_and_add("res://game/autoloads/GameConfig.gd", "GameConfig")
	logger = _instantiate_and_add("res://game/autoloads/Logger.gd", "Logger")
	bus = _instantiate_and_add("res://game/autoloads/GameBus.gd", "GameBus")

	# DataManager subsystem (owned by GameService composition root — no project.godot autoload needed)
	_instantiate_and_add("res://addons/datamanager/autoload/Config.gd", "DataManagerConfig")
	var dm_signals := _instantiate_and_add("res://addons/datamanager/autoload/Signals.gd", "DataManagerSignals")
	_instantiate_and_add("res://addons/datamanager/autoload/SyncManager.gd", "SyncManager")
	var data_manager := _instantiate_and_add("res://addons/datamanager/autoload/DataManager.gd", "DataManager")
	var data_signals: Node = dm_signals
	if bus and bus.has_method("configure"):
		bus.configure(data_signals)
	
	# 2. Initialize managers
	audio = AudioManager.new()
	audio.name = "AudioManager"
	audio.configure(logger)
	add_child(audio)
	
	game = GameManager.new()
	game.name = "GameManager"
	game.configure(logger, bus)
	add_child(game)
	
	haptics = HapticsManager.new()
	haptics.name = "HapticsManager"
	add_child(haptics)
	
	network = NetworkManager.new()
	network.name = "NetworkManager"
	network.configure(config, logger, bus)
	add_child(network)
	
	save = SaveManager.new()
	save.name = "SaveManager"
	save.configure(data_manager, data_signals, logger)
	add_child(save)
	
	scene = SceneManager.new()
	scene.name = "SceneManager"
	scene.configure(logger, registry)
	add_child(scene)
	
	ui = UIManager.new()
	ui.name = "UIManager"
	ui.configure(logger, bus, audio, game)
	add_child(ui)
	
	_register_services()
	_add_lockdown_services()
	_inject_into_new_nodes()
	logger.info("GameService initialized")

func create_feature(feature_script: Script, parent: Node, dependencies: Dictionary) -> GameFeature:
	return FeatureFactory.create_feature(feature_script, parent, dependencies)

func _register_services() -> void:
	registry.register(&"config", config)
	registry.register(&"logger", logger)
	registry.register(&"bus", bus)
	registry.register(&"audio", audio)
	registry.register(&"game", game)
	registry.register(&"haptics", haptics)
	registry.register(&"network", network)
	registry.register(&"save", save)
	registry.register(&"scene", scene)
	registry.register(&"ui", ui)

# ── Lockdown game services ─────────────────────────────────────────────────
# key -> script. Created in this order; each one gets inject_services() before it enters the tree,
# so its _ready() can already use the others.
const LOCKDOWN_SERVICES := {
	&"settings": "res://game/scripts/managers/SettingsManager.gd",
	&"input": "res://game/scripts/managers/InputManager.gd",
	&"time": "res://game/scripts/managers/TimeManager.gd",
	&"debug": "res://game/scripts/managers/DebugTools.gd",
	&"noise": "res://game/scripts/managers/NoiseBus.gd",
	&"checkpoint": "res://game/scripts/managers/CheckpointManager.gd",
	&"subtitle": "res://game/scripts/managers/SubtitleManager.gd",
	&"spatial_audio": "res://game/scripts/managers/SpatialAudioManager.gd",
}

func _add_lockdown_services() -> void:
	var nodes: Array[Node] = []
	for key in LOCKDOWN_SERVICES:
		var node: Node = load(LOCKDOWN_SERVICES[key]).new()
		node.name = LOCKDOWN_SERVICES[key].get_file().get_basename()
		registry.register(key, node)
		nodes.append(node)
	for node in nodes:
		if node.has_method("inject_services"):
			node.inject_services(registry)
	for node in nodes:
		add_child(node)

## Pattern 2 auto-wiring for every node, not only scenes loaded by SceneManager: runtime-spawned
## nodes and scenes started directly (editor F6, tests) get inject_services() on entering the tree,
## i.e. before their _ready(). Controllers still run _on_ready() only once they are ready.
func _inject_into_new_nodes() -> void:
	get_tree().node_added.connect(_on_node_added)
	for node in get_tree().root.find_children("*", "", true, false):
		_on_node_added(node)

func _on_node_added(node: Node) -> void:
	if node.has_method("inject_services") and node.get_parent() != self:
		node.inject_services(registry)

func _instantiate_and_add(script_path: String, node_name: String) -> Node:
	var script = load(script_path)
	if script == null:
		push_error("GameService: Failed to load " + script_path)
		return null
		
	var node = script.new()
	if node is Node:
		node.name = node_name
		add_child(node)
	return node
