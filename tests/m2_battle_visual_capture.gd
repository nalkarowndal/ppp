extends SceneTree
## M2-5 real-renderer capture under Xvfb, NOT Android/Windows physical QA.
const BattleScene = preload("res://scenes/battle_m2_5.tscn")

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var value: String = OS.get_environment("M2_5_VISUAL_SIZE")
	if value.is_empty():
		value = "360x800"
	var parts: PackedStringArray = value.split("x")
	if parts.size() != 2:
		_fail("invalid size string")
		return
	var wanted: Vector2i = Vector2i(int(parts[0]), int(parts[1]))
	if wanted.x < 300 or wanted.y < 500:
		_fail("invalid viewport dimensions")
		return
	root.size = wanted
	DisplayServer.window_set_size(wanted)
	var phase: String = OS.get_environment("M2_5_VISUAL_PHASE")
	if phase.is_empty():
		phase = "initial"
	if not phase in ["initial", "combat", "controls"]:
		_fail("unknown visual phase")
		return
	var ui: Control = BattleScene.instantiate()
	root.add_child(ui)
	ui.set_process(false)
	for i in range(6):
		await process_frame
	if phase != "initial":
		ui.call("advance_ticks", 70)
		for i in range(3):
			await process_frame
	if phase == "controls":
		var scroll: ScrollContainer = ui.find_child("BattleScroll", true, false)
		if scroll == null:
			_fail("battle scroll panel missing")
			return
		scroll.scroll_vertical = 10000
		for i in range(4):
			await process_frame
	var image: Image = root.get_texture().get_image()
	if image.is_empty() or image.get_width() < wanted.x or image.get_height() < wanted.y:
		_fail("viewport screenshot is empty or incomplete")
		return
	var colors: Dictionary = {}
	for y in range(0, image.get_height(), maxi(1, int(image.get_height() / 16))):
		for x in range(0, image.get_width(), maxi(1, int(image.get_width() / 12))):
			var c: Color = image.get_pixel(x, y)
			colors[c.to_html(false)] = true
	if colors.size() < 4:
		_fail("screen capture is blank or nearly uniform; sample colors=%d" % colors.size())
		return
	var folder: String = ProjectSettings.globalize_path("res://qa_artifacts")
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		_fail("could not create QA artifact directory")
		return
	var path: String = folder.path_join("m2_5_battle_%dx%d_%s.png" % [wanted.x, wanted.y, phase])
	if image.save_png(path) != OK:
		_fail("PNG write failed")
		return
	print("M2-5 VISUAL CAPTURE PASS: size=%dx%d phase=%s colors=%d path=%s (Xvfb only)" % [image.get_width(), image.get_height(), phase, colors.size(), path])
	ui.queue_free()
	quit(0)

func _fail(reason: String) -> void:
	push_error("M2-5 VISUAL CAPTURE FAIL: " + reason)
	quit(1)
