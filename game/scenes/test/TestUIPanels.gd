extends SceneTree

## Project: Lockdown - UI panel flow (template UIManager / GameManager)
## 1. HUD indicator and objective text are nodes in Hud.tscn, not created at runtime
## 2. Pause pushes PauseMenu, settings stacks on top and Back returns, resume empties the stack
## 3. Death pushes DeathScreen (GAME_OVER); its Restart respawns and closes it (PLAYING)
## 4. Level exit pushes LevelClearScreen; Restart reloads the level with an empty stack
## 5. Quit from the pause menu goes Home with an empty stack and GameManager IDLE

const FLOOR := "res://game/scenes/gameplay/levels/Floor01.tscn"

var passed_count: int = 0
var failed_count: int = 0
var ui: UIManager
var game: GameManager
var im: InputManager
var cm: CheckpointManager

func _init() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	await TestServices.start(self)
	ui = TestServices.get_service(self, &"ui")
	game = TestServices.get_service(self, &"game")
	im = TestServices.get_service(self, &"input")
	cm = TestServices.get_service(self, &"checkpoint")
	print("\n=== STARTING UI PANEL TEST SUITE ===\n")
	await _run("Test 1: HUD nodes live in the scene file", _test_hud_nodes)
	await _run("Test 2: Pause, settings, back, resume", _test_pause_flow)
	await _run("Test 3: Death screen and restart", _test_death_flow)
	await _run("Test 4: Level clear and restart", _test_level_clear)
	await _run("Test 5: Quit to Home", _test_quit_home)
	print("\nRESULTS: %d Passed, %d Failed\n" % [passed_count, failed_count])
	quit(0 if failed_count == 0 else 1)

func _run(title: String, test: Callable) -> void:
	print("--- %s ---" % title)
	var ok: bool = await test.call()
	if ok:
		passed_count += 1
		print("PASSED")
	else:
		failed_count += 1
		print("FAILED: %s" % title)

func _fail(msg: String) -> bool:
	printerr("  " + msg)
	return false

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _load_floor() -> void:
	ui.get_parent().get_node("SceneManager").go_to(FLOOR)
	await _frames(40)

func _test_hud_nodes() -> bool:
	var hud: Node = load("res://game/scenes/ui/mfw/Hud.tscn").instantiate() # not in the tree: no _ready
	var ok := true
	if not (hud.get_node_or_null("DamageDirectionIndicator") is DamageDirectionIndicator):
		ok = _fail("DamageDirectionIndicator is not a node in Hud.tscn")
	if not (hud.get_node_or_null("ObjectiveDisplay") is ObjectiveDisplay):
		ok = _fail("ObjectiveDisplay is not a node in Hud.tscn")
	if hud.get_node_or_null("PauseMenu") or hud.get_node_or_null("DeathContainer"):
		ok = _fail("Pause/death panels should no longer be embedded in the HUD")
	hud.free()
	return ok

func _test_pause_flow() -> bool:
	await _load_floor()
	if game.state != GameManager.State.PLAYING:
		return _fail("Level did not start a PLAYING session (state %s)" % GameManager.State.keys()[game.state])
	im.pause_gameplay()
	await _frames(2)
	if not (ui.current() is PauseMenu) or not paused or game.state != GameManager.State.PAUSED:
		return _fail("Pause did not push PauseMenu / pause the game")
	(ui.current() as PauseMenu)._on_settings_pressed()
	await _frames(2)
	if not (ui.current() is SettingsMenu) or ui.stack_size() != 2:
		return _fail("Settings did not stack on the pause menu")
	(ui.current() as SettingsMenu)._on_back_pressed()
	await _frames(2)
	if not (ui.current() is PauseMenu) or not ui.current().visible:
		return _fail("Back did not return to a visible pause menu")
	(ui.current() as PauseMenu)._on_resume_pressed()
	await _frames(2)
	if ui.stack_size() != 0 or paused or game.state != GameManager.State.PLAYING:
		return _fail("Resume left %d panel(s) open / still paused" % ui.stack_size())
	return true

func _test_death_flow() -> bool:
	await cm.handle_player_death()
	await _frames(2)
	if not (ui.current() is DeathScreen) or game.state != GameManager.State.GAME_OVER:
		return _fail("Death did not push DeathScreen / set GAME_OVER")
	var ds := ui.current() as DeathScreen
	await create_timer(DeathScreen.INPUT_DELAY + 0.1).timeout
	if not ds.is_input_ready():
		return _fail("Death screen never accepted input")
	ds._on_restart_pressed()
	await _frames(3)
	if ui.stack_size() != 0 or game.state != GameManager.State.PLAYING or im.is_death_screen_active:
		return _fail("Restart did not close the death screen and resume play")
	return true

func _test_level_clear() -> bool:
	var exit: LevelExitTrigger = current_scene.find_child("*Exit*", true, false) as LevelExitTrigger
	if exit == null:
		for n in current_scene.find_children("*", "Area3D", true, false):
			if n is LevelExitTrigger:
				exit = n
	if exit == null:
		return _fail("No LevelExitTrigger in Floor 1")
	exit.trigger_clear()
	await _frames(2)
	if not (ui.current() is LevelClearScreen) or not paused:
		return _fail("Level exit did not push LevelClearScreen / pause")
	var lc := ui.current() as LevelClearScreen
	await create_timer(0.4).timeout
	lc._on_restart_pressed()
	await _frames(40)
	if ui.stack_size() != 0 or paused or current_scene.scene_file_path != FLOOR:
		return _fail("Restart did not reload Floor 1 with an empty UI stack")
	if game.state != GameManager.State.PLAYING:
		return _fail("Reloaded level is not PLAYING")
	return true

func _test_quit_home() -> bool:
	im.pause_gameplay()
	await _frames(2)
	(ui.current() as PauseMenu)._on_quit_pressed()
	await _frames(40)
	if current_scene.scene_file_path != "res://game/scenes/Home/Home.tscn":
		return _fail("Quit did not go to Home (at %s)" % current_scene.scene_file_path)
	if ui.stack_size() != 0 or paused or game.state != GameManager.State.IDLE:
		return _fail("Home has %d panel(s) open / paused / state %s" % [ui.stack_size(), GameManager.State.keys()[game.state]])
	return true
