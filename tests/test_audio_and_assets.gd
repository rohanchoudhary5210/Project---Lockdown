@tool
extends SceneTree

func _init() -> void:
	print("=== Running Audio and Asset Validation Test ===")
	
	# 1. Verify all procedural materials exist and load
	var mats = [
		"res://assets/procedural/materials/mat_concrete_wall.tres",
		"res://assets/procedural/materials/mat_plaster_wall.tres",
		"res://assets/procedural/materials/mat_tiled_floor.tres",
		"res://assets/procedural/materials/mat_ceiling.tres",
		"res://assets/procedural/materials/mat_metal.tres",
		"res://assets/procedural/materials/mat_wood.tres",
		"res://assets/procedural/materials/mat_damage_vignette.tres",
		"res://assets/procedural/materials/mat_muzzle_flash.tres"
	]
	for m_path in mats:
		var res = load(m_path)
		assert(res != null, "Failed to load material: " + m_path)
		print("Loaded material OK: ", m_path)
	
	# 2. Verify all procedural audio streams exist and load
	var audios = [
		"res://assets/procedural/audio/sfx_pistol_shot.tres",
		"res://assets/procedural/audio/sfx_rifle_shot.tres",
		"res://assets/procedural/audio/sfx_dry_fire.tres",
		"res://assets/procedural/audio/sfx_reload.tres",
		"res://assets/procedural/audio/sfx_melee_swing.tres",
		"res://assets/procedural/audio/sfx_melee_hit.tres",
		"res://assets/procedural/audio/sfx_parry_clang.tres",
		"res://assets/procedural/audio/sfx_block_thud.tres",
		"res://assets/procedural/audio/sfx_footstep_1.tres",
		"res://assets/procedural/audio/sfx_footstep_2.tres",
		"res://assets/procedural/audio/sfx_footstep_3.tres",
		"res://assets/procedural/audio/sfx_footstep_4.tres",
		"res://assets/procedural/audio/sfx_pickup.tres",
		"res://assets/procedural/audio/sfx_checkpoint_chime.tres",
		"res://assets/procedural/audio/sfx_heartbeat.tres",
		"res://assets/procedural/audio/amb_building_hum.tres"
	]
	for a_path in audios:
		var stream = load(a_path)
		assert(stream is AudioStreamWAV, "Resource is not AudioStreamWAV: " + a_path)
		assert(stream.data.size() > 0, "Audio stream data is empty: " + a_path)
		print("Loaded audio stream OK (%d bytes, loop=%s): %s" % [stream.data.size(), str(stream.loop_mode), a_path])
	
	# 3. Verify Theme
	var theme = load("res://assets/procedural/ui/theme/lockdown_theme.tres")
	assert(theme is Theme, "Theme failed to load")
	print("Theme loaded OK: res://assets/procedural/ui/theme/lockdown_theme.tres")
	
	# 4. Verify scenes load without error
	var scenes = [
		"res://scenes/ui/main_menu.tscn",
		"res://scenes/ui/hud.tscn",
		"res://scenes/ui/pause_menu.tscn",
		"res://scenes/ui/settings_menu.tscn",
		"res://scenes/levels/floor_01.tscn"
	]
	for s_path in scenes:
		var scn = load(s_path)
		assert(scn is PackedScene, "Scene failed to load: " + s_path)
		print("Loaded scene OK: ", s_path)
	
	print("=== All Validations Passed Successfully! ===")
	quit(0)
