extends SceneTree

## Phones send each first-finger tap twice: as a touch AND as an emulated mouse click.
## Taps the crouch toggle the way a phone does and checks it flips exactly once per tap.

var f := 0
var b: TouchButton
var c := Vector2.ZERO
var taps := 0
var presses := 0
var failed := false

func _init() -> void:
	Input.emulate_mouse_from_touch = true
	change_scene_to_file("res://game/scenes/gameplay/levels/Floor01.tscn")

func _send(pressed: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.index = 0
	t.position = c
	t.pressed = pressed
	Input.parse_input_event(t)

func _process(_d: float) -> bool:
	f += 1
	if f == 3:
		root.size = Vector2i(2400, 1080)
	elif f == 12:
		var tc = current_scene.find_child("TouchControls", true, false)
		tc.visible = true
		tc._update_layout_and_safe_area()
	elif f == 14:
		var tc = current_scene.find_child("TouchControls", true, false)
		b = tc.crouch_button
		b.button_pressed.connect(func(): presses += 1)
		c = root.get_final_transform() * (b.get_global_transform_with_canvas() * (b.size * 0.5))
	elif f >= 20 and taps < 4:
		var phase := (f - 20) % 6
		if phase == 0:
			_send(true)
		elif phase == 3:
			_send(false)
		elif phase == 5:
			taps += 1
			var expect_on := taps % 2 == 1
			if presses != taps or b.is_pressed != expect_on or Input.is_action_pressed("crouch") != expect_on:
				printerr("Tap %d: crouch on=%s (expected %s), press calls=%d (expected %d)" % [taps, b.is_pressed, expect_on, presses, taps])
				failed = true
	if taps >= 4:
		if failed:
			print("RESULTS: 0 Passed, 1 Failed")
		else:
			print("PASSED: crouch toggle flips once per phone tap")
			print("RESULTS: 1 Passed, 0 Failed")
		quit(1 if failed else 0)
	return false
