extends SceneTree
## M1 headless UI integration check; it cannot replace real visual QA.
const Save = preload("res://scripts/core/save_manager.gd")
const MainScene = preload("res://scenes/main.tscn")

func _initialize() -> void:
	call_deferred("_run_tests")

func _run_tests() -> void:
	var main: Node = MainScene.instantiate()
	root.add_child(main)
	await process_frame

	var roster: Array = main.get("_roster")
	if roster.size() != 8:
		_fail("expected 8 roster characters")
		return

	var step_button: Button = _find_button(main, "1턴 진행 (디버그)")
	var reset_button: Button = _find_button(main, "초기화")
	var save_button: Button = _find_button(main, "샌드박스 턴 번호 저장")
	if step_button == null or reset_button == null or save_button == null:
		_fail("required action button is missing")
		return

	step_button.pressed.emit()
	var status_label: Label = main.get("_status_label")
	if not status_label.text.contains("턴 1"):
		_fail("step button didn't advance sandbox")
		return
	reset_button.pressed.emit()
	if not status_label.text.contains("턴 0"):
		_fail("reset button didn't reset sandbox")
		return
	step_button.pressed.emit()
	save_button.pressed.emit()
	var state: Dictionary = Save.load_debug_state()
	if int(state.get("schema_version", 0)) != 1 or int(state.get("sandbox_turn", -1)) != 1:
		_fail("development save did not round-trip")
		return
	main.queue_free()
	await process_frame

	var restored: Node = MainScene.instantiate()
	root.add_child(restored)
	await process_frame
	var save_label: Label = restored.get("_save_label")
	if not save_label.text.contains("1턴"):
		_fail("reopened UI did not display saved turn")
		return
	print("UI INTEGRATION PASS: 8 characters, button signals, reset, save, reopen")
	restored.queue_free()
	quit(0)

func _find_button(parent: Node, text_to_match: String) -> Button:
	for node in parent.find_children("*", "Button", true, false):
		if node is Button and node.text == text_to_match:
			return node
	return null

func _fail(message: String) -> void:
	push_error("UI INTEGRATION FAIL: " + message)
	quit(1)
