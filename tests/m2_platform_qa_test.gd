extends SceneTree
## The emulator needs real projected screen coordinates, not guessed tap positions.
const Main = preload("res://scenes/main.tscn")
const Battle = preload("res://scenes/battle_m2_5.tscn")

func _initialize() -> void:
	call_deferred("_check")

func _check() -> void:
	var main: Control = Main.instantiate()
	root.add_child(main)
	await process_frame
	var ok: bool = main.has_method("_qa_emit_m2_target")
	if not ok:
		_fail("M1 launcher needs M2 projected entry target telemetry")
		return
	var preview: Control = Battle.instantiate()
	root.add_child(preview)
	preview.set_process(false)
	await process_frame
	if not preview.has_method("_qa_emit_targets"):
		_fail("M2 screen needs projected touch target telemetry")
		return
	if not preview.has_method("_qa_target"):
		_fail("M2 screen needs visible scroll-clipped target geometry")
		return
	print("M2-5 PLATFORM INSTRUMENTATION PASS: on-screen target projection for emulator touch QA")
	preview.queue_free()
	main.queue_free()
	quit(0)

func _fail(message: String) -> void:
	push_error("M2-5 PLATFORM INSTRUMENTATION FAIL: " + message)
	quit(1)
