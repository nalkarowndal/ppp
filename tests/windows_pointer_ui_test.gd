extends SceneTree
## Windows CI: dispatch actual InputEventMouseButton press/release into Godot's
## GUI input routing. This is NOT a real OS desktop/Win32 mouse or visual test.
const MainScene = preload("res://scenes/main.tscn")
const Save = preload("res://scripts/core/save_manager.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var main: Control = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	var step: Button = main.get("_qa_step_button")
	var reset: Button = main.get("_qa_reset_button")
	var save: Button = main.get("_qa_save_button")
	if step == null or reset == null or save == null:
		_fail("M1 button references not found")
		return
	var scroll: ScrollContainer = main.get("_qa_scroll")
	for btn in [step, reset, save]:
		if not scroll.get_global_rect().has_point(btn.get_global_rect().get_center()):
			_fail("button center is clipped: " + btn.text)
			return
	await _click(step)
	if not _assert_turn(main, 1, "STEP"):
		return
	await _click(reset)
	if not _assert_turn(main, 0, "RESET"):
		return
	await _click(step)
	if not _assert_turn(main, 1, "STEP after RESET"):
		return
	await _click(save)
	var saved: Dictionary = Save.load_debug_state()
	if int(saved.get("sandbox_turn", -1)) != 1 or int(saved.get("schema_version", -1)) != 1:
		_fail("button input did not persist sandbox_turn=1")
		return
	var save_label: Label = main.get("_save_label")
	if not save_label.text.contains("성공"):
		_fail("no visible save success label")
		return
	main.queue_free()
	await process_frame
	var restored: Control = MainScene.instantiate()
	root.add_child(restored)
	await process_frame
	await process_frame
	var restored_label: Label = restored.get("_save_label")
	if not restored_label.text.contains("1턴"):
		_fail("new scene did not restore saved turn 1")
		return
	print("WINDOWS POINTER UI PASS: press/release routed to STEP RESET STEP SAVE and saved turn restored")
	restored.queue_free()
	quit(0)

func _click(target: Button) -> void:
	var viewport: Viewport = root
	var point: Vector2 = target.get_global_transform_with_canvas() * (target.size * 0.5)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	viewport.push_input(motion, true)
	await process_frame
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.button_mask = MOUSE_BUTTON_MASK_LEFT
	down.position = point
	down.global_position = point
	down.pressed = true
	viewport.push_input(down, true)
	await process_frame
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.button_mask = 0
	up.position = point
	up.global_position = point
	up.pressed = false
	viewport.push_input(up, true)
	await process_frame
	print("WINDOWS POINTER INPUT: %s x=%d y=%d" % [target.text, roundi(point.x), roundi(point.y)])

func _assert_turn(main: Node, expected: int, action: String) -> bool:
	var label: Label = main.get("_status_label")
	if not label.text.contains("턴 %d" % expected):
		_fail("%s missing turn %d (got %s)" % [action, expected, label.text])
		return false
	return true

func _fail(message: String) -> void:
	push_error("WINDOWS POINTER UI FAIL: " + message)
	quit(1)
