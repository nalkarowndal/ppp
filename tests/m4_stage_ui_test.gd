extends SceneTree
## M4 human-facing portrait stage selection and live M2 battle/result feedback.
const PATH: String = "user://qa_m4/ui_profile.json"
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute("user://qa_m4")
	for path in [PATH, PATH + ".bak", PATH + ".tmp", PATH + ".bak.tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	var packed: PackedScene = load("res://scenes/m4_stage.tscn")
	_assert(packed != null, "M4 stage portrait scene exists")
	if packed == null:
		_finish()
		return
	var screen: Control = packed.instantiate()
	screen.profile_path = PATH
	root.add_child(screen)
	await process_frame
	var first: Button = screen.find_child("StageButton1", true, false)
	var second: Button = screen.find_child("StageButton2", true, false)
	_assert(first != null and second != null, "two stage controls are present")
	if first != null and second != null:
		_assert(not first.disabled and second.disabled, "stage one available, stage two initially locked")
		first.pressed.emit()
		await process_frame
		_assert(int(screen.current_stage()) == 1, "touch stage one starts a real fight")
		for _i in range(12):
			if str(screen.advance_ticks(200).get("state", "")) != "running":
				break
		await process_frame
		_assert(not second.disabled, "victory unlocks the next stage in the scene")
		var result_label: Label = screen.find_child("RewardResult", true, false)
		_assert(result_label != null and result_label.text.contains("골드"), "saved reward appears in the screen")
	screen.queue_free()
	await process_frame
	_finish()

func _assert(ok: bool, description: String) -> void:
	if not ok:
		failures.append(description)
		printerr("M4 UI FAIL: " + description)

func _finish() -> void:
	if failures.is_empty():
		print("M4 UI PASS: portrait stage buttons, live battle victory and paid reward")
		quit(0)
	else:
		printerr("M4 UI FAIL: " + str(failures))
		quit(1)
