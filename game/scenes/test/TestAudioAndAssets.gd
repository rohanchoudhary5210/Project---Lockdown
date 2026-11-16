@tool
extends SceneTree

func _init() -> void:
	print("=== Running Audio and Asset Validation Test ===")
	
	# 1. Verify all procedural materials exist and load
	var mats = [
		"res://game/assets/materials/procedural/mat_concrete_wall.tres",
		"res://game/assets/materials/procedural/mat_plaster_wall.tres",
		"res://game/assets/materials/procedural/mat_tiled_floor.tres",
		"res://game/assets/materials/procedural/mat_ceiling.tres",
		"res://game/assets/materials/procedural/mat_metal.tres",
		"res://game/assets/materials/procedural/mat_wood.tres",
		"res://game/assets/materials/procedural/mat_damage_vignette.tres",
		"res://game/assets/materials/procedural/mat_muzzle_flash.tres"
	]
	for m_path in mats:
		var res = load(m_path)
		assert(res != null, "Failed to load material: " + m_path)
		print("Loaded material OK: ", m_path)
	
	# 2. Verify all procedural audio streams exist and load
	var audios = [
		"res://game/assets/audio/procedural/sfx_pistol_shot.tres",
		"res://game/assets/audio/procedural/sfx_rifle_shot.tres",
		"res://game/assets/audio/procedural/sfx_dry_fire.tres",
		"res://game/assets/audio/procedural/sfx_reload.tres",
		"res://game/assets/audio/procedural/sfx_melee_swing.tres",
		"res://game/assets/audio/procedural/sfx_melee_hit.tres",
		"res://game/assets/audio/procedural/sfx_parry_clang.tres",
		"res://game/assets/audio/procedural/sfx_block_thud.tres",
		"res://game/assets/audio/procedural/sfx_footstep_1.tres",
		"res://game/assets/audio/procedural/sfx_footstep_2.tres",
		"res://game/assets/audio/procedural/sfx_footstep_3.tres",
		"res://game/assets/audio/procedural/sfx_footstep_4.tres",
		"res://game/assets/audio/procedural/sfx_pickup.tres",
		"res://game/assets/audio/procedural/sfx_checkpoint_chime.tres",
		"res://game/assets/audio/procedural/sfx_heartbeat.tres",
		"res://game/assets/audio/procedural/amb_building_hum.tres"
	]
	for a_path in audios:
		var stream = load(a_path)
		assert(stream is AudioStreamWAV, "Resource is not AudioStreamWAV: " + a_path)
		assert(stream.data.size() > 0, "Audio stream data is empty: " + a_path)
		print("Loaded audio stream OK (%d bytes, loop=%s): %s" % [stream.data.size(), str(stream.loop_mode), a_path])
	
	# 3. Verify Theme
	var theme = load("res://game/assets/ui/lockdown_theme.tres")
	assert(theme is Theme, "Theme failed to load")
	print("Theme loaded OK: res://game/assets/ui/lockdown_theme.tres")
	
	# 4. Verify scenes load without error
	var scenes = [
		"res://game/scenes/Home/Home.tscn",
		"res://game/scenes/ui/mfw/Hud.tscn",
		"res://game/scenes/ui/mfw/PauseMenu.tscn",
		"res://game/scenes/ui/mfw/SettingsMenu.tscn",
		"res://game/scenes/gameplay/levels/Floor01.tscn"
	]
	for s_path in scenes:
		var scn = load(s_path)
		assert(scn is PackedScene, "Scene failed to load: " + s_path)
		print("Loaded scene OK: ", s_path)
	
	print("=== All Validations Passed Successfully! ===")
	quit(0)
