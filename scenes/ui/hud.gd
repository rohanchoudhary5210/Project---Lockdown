class_name HUD
extends Control

## Project: Lockdown - HUD Component (Milestone 3)
## Displays health bar, ammo counter, crosshair, interaction prompt, and damage flash.

@onready var health_bar: ProgressBar = $HealthContainer/Margin/VBox/HealthBar
@onready var health_label: Label = $HealthContainer/Margin/VBox/HBox/HealthLabel
@onready var health_icon: Control = %HealthIcon
@onready var ammo_label: Label = $AmmoContainer/Margin/HBox/AmmoLabel
@onready var ammo_icon: Control = %AmmoIcon
@onready var interact_container: PanelContainer = $InteractContainer
@onready var interact_label: Label = $InteractContainer/Margin/HBox/InteractLabel
@onready var damage_flash: ColorRect = $DamageFlash
@onready var crosshair: Control = $Crosshair
@onready var pause_menu: Control = get_node_or_null("PauseMenu")
@onready var pause_container: Control = pause_menu
@onready var touch_controls: Control = get_node_or_null("TouchControls")
@onready var checkpoint_container: PanelContainer = $CheckpointContainer
@onready var checkpoint_label: Label = $CheckpointContainer/Margin/CheckpointLabel
@onready var invuln_label: Label = $InvulnerabilityLabel
@onready var death_overlay: ColorRect = $DeathOverlay
@onready var death_container: Control = $DeathContainer
@onready var restart_button: Button = $DeathContainer/Center/VBox/RestartButton
@onready var death_hint: Label = $DeathContainer/Center/VBox/Hint
@onready var progress_ring: ProgressRing = $Crosshair/ProgressRing
@onready var subtitle_container: PanelContainer = $SubtitleContainer
@onready var subtitle_label: RichTextLabel = $SubtitleContainer/Margin/SubtitleLabel

var _vignette_intensity: float = 0.0
var _low_hp_desat: float = 0.0
var _pulse_timer: float = 0.0
var _death_screen_input_ready: bool = false
var _death_key_must_release: bool = false
var _last_vp_size: Vector2 = Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if interact_container:
		interact_container.visible = false
	if damage_flash:
		damage_flash.visible = false
	if pause_container:
		pause_container.visible = false
	if checkpoint_container:
		checkpoint_container.visible = false
		checkpoint_container.modulate.a = 0.0
	if invuln_label:
		invuln_label.visible = false
	if death_overlay:
		death_overlay.modulate.a = 0.0
	if death_container:
		death_container.visible = false
	if subtitle_container:
		subtitle_container.visible = false
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	
	var vp = get_viewport()
	if vp and not vp.size_changed.is_connected(_update_layout_and_safe_area):
		vp.size_changed.connect(_update_layout_and_safe_area)
	
	_update_layout_and_safe_area()
	call_deferred("_connect_signals")

func _enter_tree() -> void:
	# Ensure HUD is inside a CanvasLayer (layer 0) so root Control anchors work natively
	var p = get_parent()
	if p and not (p is CanvasLayer) and not (p is Viewport) and not (p is Control):
		var cl = CanvasLayer.new()
		cl.name = "UI"
		cl.layer = 0
		p.call_deferred("add_child", cl)
		call_deferred("_reparent_to_layer", cl)

func _reparent_to_layer(cl: CanvasLayer) -> void:
	if is_inside_tree() and cl and is_instance_valid(cl) and get_parent() != cl:
		reparent(cl)
		set_anchors_preset(Control.PRESET_FULL_RECT)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_layout_and_safe_area()

func _update_layout_and_safe_area() -> void:
	var vp_size: Vector2 = get_viewport_rect().size
	if vp_size.x <= 0 or vp_size.y <= 0:
		return
	
	_last_vp_size = vp_size
	set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Safe area insets (respect notch, cutouts, rounded corners, at least 24px margin)
	var safe_area: Rect2i = DisplayServer.get_display_safe_area()
	var window_size: Vector2i = DisplayServer.window_get_size()
	if window_size.x <= 0 or window_size.y <= 0:
		window_size = Vector2i(int(vp_size.x), int(vp_size.y))
	if safe_area.size.x <= 0 or safe_area.size.y <= 0:
		safe_area = Rect2i(Vector2i.ZERO, window_size)
	
	var scale_x: float = vp_size.x / float(window_size.x)
	var scale_y: float = vp_size.y / float(window_size.y)
	
	var safe_left_px: float = maxf(float(safe_area.position.x), 0.0) * scale_x
	var safe_top_px: float = maxf(float(safe_area.position.y), 0.0) * scale_y
	var safe_right_px: float = maxf(float(window_size.x - safe_area.end.x), 0.0) * scale_x
	var safe_bottom_px: float = maxf(float(window_size.y - safe_area.end.y), 0.0) * scale_y
	
	var margin_left: float = safe_left_px + 24.0
	var margin_right: float = safe_right_px + 24.0
	var margin_bottom: float = safe_bottom_px + 24.0
	var margin_top: float = safe_top_px + 24.0
	
	# Position HealthContainer safely
	var health_container = get_node_or_null("HealthContainer") as Control
	if health_container:
		var w: float = maxf(health_container.size.x, 210.0)
		var h: float = maxf(health_container.size.y, 60.0)
		health_container.offset_left = margin_left
		health_container.offset_right = margin_left + w
		health_container.offset_bottom = -margin_bottom
		health_container.offset_top = -margin_bottom - h
	
	# Position AmmoContainer safely
	var ammo_container = get_node_or_null("AmmoContainer") as Control
	if ammo_container:
		var w: float = maxf(ammo_container.size.x, 160.0)
		var h: float = maxf(ammo_container.size.y, 60.0)
		ammo_container.offset_right = -margin_right
		ammo_container.offset_left = -margin_right - w
		ammo_container.offset_bottom = -margin_bottom
		ammo_container.offset_top = -margin_bottom - h
	
	# Position TouchControls PauseButton safely
	if touch_controls:
		var pb = touch_controls.get_node_or_null("%PauseButton")
		if pb:
			pb.offset_left = margin_left
			pb.offset_top = margin_top
			pb.offset_right = margin_left + 64.0
			pb.offset_bottom = margin_top + 64.0

func _process(delta: float) -> void:
	var current_vp_size = get_viewport_rect().size
	if current_vp_size != _last_vp_size:
		_update_layout_and_safe_area()
	if _vignette_intensity > 0.0:
		_vignette_intensity = max(_vignette_intensity - delta * 3.2, 0.0)
	
	var pulse_amount: float = 0.0
	if _low_hp_desat > 0.0:
		_pulse_timer += delta * 4.5
		pulse_amount = (sin(_pulse_timer) * 0.5 + 0.5) * _low_hp_desat
	else:
		_pulse_timer = 0.0
	
	if damage_flash:
		if damage_flash.material is ShaderMaterial:
			var mat = damage_flash.material as ShaderMaterial
			mat.set_shader_parameter("vignette_intensity", _vignette_intensity)
			mat.set_shader_parameter("desaturation", _low_hp_desat)
			mat.set_shader_parameter("pulse_intensity", pulse_amount)
		damage_flash.visible = (_vignette_intensity > 0.001 or _low_hp_desat > 0.001)

func _connect_signals() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	# Connect HealthComponent
	var health: HealthComponent = player.get_node_or_null("HealthComponent") as HealthComponent
	if health:
		if not health.health_changed.is_connected(_on_health_changed):
			health.health_changed.connect(_on_health_changed)
		if not health.damaged.is_connected(_on_damaged):
			health.damaged.connect(_on_damaged)
		_on_health_changed(health.current_health, health.max_health)
	
	# Connect WeaponController
	var weapon: WeaponController = player.find_child("Pistol", true, false) as WeaponController
	if weapon:
		if not weapon.ammo_changed.is_connected(_on_ammo_changed):
			weapon.ammo_changed.connect(_on_ammo_changed)
		if not weapon.reload_started.is_connected(_on_reload_started):
			weapon.reload_started.connect(_on_reload_started)
		if not weapon.reload_completed.is_connected(_on_reload_completed):
			weapon.reload_completed.connect(_on_reload_completed)
		if not weapon.dry_fired.is_connected(_on_dry_fired):
			weapon.dry_fired.connect(_on_dry_fired)
		_on_ammo_changed(weapon.current_ammo, weapon.reserve_ammo)
	
	# Connect Player interactions
	if player.has_signal("interaction_prompt_changed"):
		if not player.interaction_prompt_changed.is_connected(_on_interaction_prompt_changed):
			player.interaction_prompt_changed.connect(_on_interaction_prompt_changed)
	if player.has_signal("rescue_progress_changed"):
		if not player.rescue_progress_changed.is_connected(set_rescue_progress):
			player.rescue_progress_changed.connect(set_rescue_progress)
	
	# Connect InputManager pause
	var im: Node = get_node_or_null("/root/InputManager")
	if im and im.has_signal("pause_toggled"):
		if not im.pause_toggled.is_connected(_on_pause_toggled):
			im.pause_toggled.connect(_on_pause_toggled)
	
	# Connect CheckpointManager
	var cm: Node = get_node_or_null("/root/CheckpointManager")
	if cm:
		if cm.has_signal("checkpoint_activated") and not cm.checkpoint_activated.is_connected(_on_checkpoint_activated):
			cm.checkpoint_activated.connect(_on_checkpoint_activated)
		if cm.has_signal("player_death_started") and not cm.player_death_started.is_connected(_on_player_death_started):
			cm.player_death_started.connect(_on_player_death_started)
		if cm.has_signal("death_screen_shown") and not cm.death_screen_shown.is_connected(_on_death_screen_shown):
			cm.death_screen_shown.connect(_on_death_screen_shown)
		if cm.has_signal("player_respawned") and not cm.player_respawned.is_connected(_on_player_respawned):
			cm.player_respawned.connect(_on_player_respawned)
		if cm.has_signal("invulnerability_changed") and not cm.invulnerability_changed.is_connected(_on_invulnerability_changed):
			cm.invulnerability_changed.connect(_on_invulnerability_changed)
	
	# Connect SubtitleManager
	var sm: Node = get_node_or_null("/root/SubtitleManager")
	if sm:
		if sm.has_signal("subtitle_started") and not sm.subtitle_started.is_connected(_on_subtitle_started):
			sm.subtitle_started.connect(_on_subtitle_started)
		if sm.has_signal("subtitle_cleared") and not sm.subtitle_cleared.is_connected(_on_subtitle_cleared):
			sm.subtitle_cleared.connect(_on_subtitle_cleared)

func set_rescue_progress(val: float) -> void:
	if progress_ring:
		progress_ring.progress = val

func _on_subtitle_started(speaker: String, text: String, _duration: float) -> void:
	if subtitle_container and subtitle_label:
		subtitle_label.text = "[b]%s:[/b] %s" % [speaker, text]
		subtitle_container.visible = true

func _on_subtitle_cleared() -> void:
	if subtitle_container:
		subtitle_container.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if death_container and death_container.visible:
		if _death_key_must_release:
			if not Input.is_action_pressed("interact") and not Input.is_action_pressed("jump"):
				_death_key_must_release = false
			return
		
		if not _death_screen_input_ready:
			return
		
		if event.is_action_pressed("interact") or event.is_action_pressed("jump"):
			if not event.is_echo():
				_on_restart_pressed()
				get_viewport().set_input_as_handled()

func _on_restart_pressed() -> void:
	if not _death_screen_input_ready:
		return
	var cm = get_node_or_null("/root/CheckpointManager")
	if cm and cm.has_method("respawn_player"):
		cm.respawn_player()

func _on_checkpoint_activated(_name: String) -> void:
	show_checkpoint_notification("Checkpoint reached", 2.0)

func show_checkpoint_notification(text: String = "Checkpoint reached", duration: float = 2.0) -> void:
	if not checkpoint_container or not checkpoint_label:
		return
	
	checkpoint_label.text = text
	checkpoint_container.visible = true
	checkpoint_container.modulate.a = 0.0
	
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(checkpoint_container, "modulate:a", 1.0, 0.2)
	tween.tween_interval(duration)
	tween.tween_property(checkpoint_container, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func():
		if checkpoint_container:
			checkpoint_container.visible = false
	)

func _on_player_death_started() -> void:
	_death_screen_input_ready = false
	if crosshair:
		crosshair.visible = false
	if interact_container:
		interact_container.visible = false
	if pause_menu:
		pause_menu.close_menu()
	elif pause_container:
		pause_container.visible = false
	if touch_controls:
		touch_controls.visible = false
	
	if death_overlay:
		death_overlay.visible = true
		death_overlay.modulate.a = 0.0
		var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(death_overlay, "modulate:a", 1.0, 1.0)

func _on_death_screen_shown() -> void:
	_death_screen_input_ready = false
	_death_key_must_release = Input.is_action_pressed("interact") or Input.is_action_pressed("jump")
	if death_container:
		death_container.visible = true
	if restart_button:
		restart_button.disabled = true
	if death_hint:
		var im = get_node_or_null("/root/InputManager")
		var interact_key = im.get_action_key_label("interact") if im else "E"
		var jump_key = im.get_action_key_label("jump") if im else "Space"
		death_hint.text = "Press [%s] or [%s] to restart" % [interact_key, jump_key]
	
	# Ignore restart input for the first 0.5s after it appears
	await get_tree().create_timer(0.5, true, false, true).timeout
	if death_container and death_container.visible:
		_death_screen_input_ready = true
		if restart_button:
			restart_button.disabled = false
			restart_button.grab_focus()

func _on_player_respawned() -> void:
	_death_screen_input_ready = false
	_death_key_must_release = false
	reset_hud_states()
	if death_overlay:
		var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(death_overlay, "modulate:a", 0.0, 0.3)
		tween.tween_callback(func():
			if death_overlay:
				death_overlay.visible = false
		)

func reset_hud_states() -> void:
	_vignette_intensity = 0.0
	_low_hp_desat = 0.0
	if damage_flash:
		damage_flash.visible = false
	if ammo_label:
		ammo_label.modulate = Color.WHITE
	if ammo_icon and ammo_icon.has_method("set_icon_color"):
		ammo_icon.set_icon_color(Color(0.95, 0.75, 0.25))
	if health_icon and health_icon.has_method("set_icon_color"):
		health_icon.set_icon_color(Color(0.3, 0.9, 0.6))
	if interact_container:
		interact_container.visible = false
	if pause_menu:
		pause_menu.close_menu()
	elif pause_container:
		pause_container.visible = false
	if death_container:
		death_container.visible = false
	if checkpoint_container:
		checkpoint_container.visible = false
		checkpoint_container.modulate.a = 0.0
	if crosshair:
		crosshair.visible = true
	if progress_ring:
		progress_ring.progress = 0.0
	if subtitle_container:
		subtitle_container.visible = false
	if touch_controls:
		touch_controls._update_visibility()

func _on_invulnerability_changed(is_invuln: bool) -> void:
	if invuln_label:
		invuln_label.visible = is_invuln

func _on_pause_toggled(is_paused: bool) -> void:
	if pause_menu:
		if is_paused:
			pause_menu.open_menu()
		else:
			pause_menu.close_menu()
	elif pause_container:
		pause_container.visible = is_paused
	if crosshair:
		crosshair.visible = not is_paused
	if touch_controls:
		if touch_controls.has_method("set_paused"):
			touch_controls.set_paused(is_paused)
		else:
			touch_controls.visible = not is_paused

func _on_health_changed(current: float, max_hp: float) -> void:
	if health_bar:
		health_bar.max_value = max_hp
		health_bar.value = current
	if health_label:
		health_label.text = "%d HP" % int(current)
		var hp_col: Color
		if current <= 30.0:
			hp_col = Color(1.0, 0.25, 0.25)
		elif current <= 60.0:
			hp_col = Color(1.0, 0.85, 0.3)
		else:
			hp_col = Color(0.3, 0.9, 0.6)
		health_label.modulate = hp_col
		if health_icon and health_icon.has_method("set_icon_color"):
			health_icon.set_icon_color(hp_col)
	
	if current < 30.0:
		_low_hp_desat = clampf((30.0 - current) / 30.0 * 0.75, 0.0, 0.75)
	else:
		_low_hp_desat = 0.0

func _on_damaged(_amount: float, _source: Node) -> void:
	_vignette_intensity = 0.85

func _on_ammo_changed(current_mag: int, reserve: int) -> void:
	if ammo_label:
		ammo_label.text = "%d / %d" % [current_mag, reserve]
		var a_col = Color(1.0, 0.35, 0.35) if current_mag <= 3 else Color.WHITE
		ammo_label.modulate = a_col
		if ammo_icon and ammo_icon.has_method("set_icon_color"):
			ammo_icon.set_icon_color(Color(1.0, 0.35, 0.35) if current_mag <= 3 else Color(0.95, 0.75, 0.25))

func _on_reload_started(_duration: float) -> void:
	if ammo_label:
		ammo_label.text = "RELOADING..."
		ammo_label.modulate = Color(1.0, 0.85, 0.2)

func _on_reload_completed() -> void:
	if ammo_label:
		ammo_label.modulate = Color.WHITE

func _on_dry_fired() -> void:
	if ammo_label:
		ammo_label.modulate = Color(1.0, 0.2, 0.2)
		await get_tree().create_timer(0.15, true, false, true).timeout
		if ammo_label:
			ammo_label.modulate = Color.WHITE

func _on_interaction_prompt_changed(prompt_text: String) -> void:
	if interact_container and interact_label:
		if prompt_text.is_empty():
			interact_container.visible = false
		else:
			interact_label.text = prompt_text
			interact_container.visible = true
