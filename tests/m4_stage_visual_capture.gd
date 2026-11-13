extends SceneTree
## M4 native Godot/Xvfb portrait screenshot, NOT Windows or Android hardware QA.
const View = preload("res://scenes/m4_stage.tscn")
const PATH: String = "user://qa_m4/visual_profile.json"

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var wanted: Vector2i = Vector2i(360, 800)
	var size_string: String = OS.get_environment("M4_VISUAL_SIZE")
	if not size_string.is_empty():
		var parts: PackedStringArray = size_string.split("x")
		if parts.size() != 2:
			_fail("malformed viewport")
			return
		wanted = Vector2i(int(parts[0]), int(parts[1]))
	if wanted.x < 320 or wanted.y < 600:
		_fail("viewport is too small")
		return
	root.size = wanted
	DisplayServer.window_set_size(wanted)
	DirAccess.make_dir_recursive_absolute("user://qa_m4")
	for path in [PATH, PATH + ".bak", PATH + ".tmp", PATH + ".bak.tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	var ui: Control = View.instantiate()
	ui.profile_path = PATH
	root.add_child(ui)
	for _i in range(10):
		await process_frame
	var bounds: Rect2 = ui.get_global_rect()
	if bounds.size.x < 300 or bounds.size.y < 600:
		_fail("M4 layout did not fill the logical portrait screen")
		return
	for name in ["StageButton1", "StageButton2", "HomeButton", "GrowthButton", "SpeedButton"]:
		var button: Button = ui.find_child(name, true, false)
		if button == null or button.custom_minimum_size.y < 48:
			_fail("missing or undersized button " + name)
			return
		if not Rect2(Vector2.ZERO, Vector2(wanted)).has_point(button.get_global_rect().get_center()):
			_fail("button is outside physical-screen logical viewport: " + name)
			return
	var stage_one: Button = ui.find_child("StageButton1", true, false)
	var stage_two: Button = ui.find_child("StageButton2", true, false)
	if stage_one.disabled or not stage_two.disabled:
		_fail("stage lock state is wrong on a fresh save")
		return
	var shot: Image = root.get_texture().get_image()
	if shot.is_empty() or shot.get_width() < wanted.x or shot.get_height() < wanted.y:
		_fail("render buffer missing")
		return
	var colors: Dictionary = {}
	for y in range(0, shot.get_height(), maxi(1, int(shot.get_height() / 20))):
		for x in range(0, shot.get_width(), maxi(1, int(shot.get_width() / 15))):
			colors[shot.get_pixel(x, y).to_html(false)] = true
	if colors.size() < 5:
		_fail("screen has insufficient visible content")
		return
	var folder: String = ProjectSettings.globalize_path("res://qa_artifacts")
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		_fail("cannot create qa_artifacts")
		return
	var output: String = folder.path_join("m4_stage_portrait_%dx%d.png" % [wanted.x, wanted.y])
	if shot.save_png(output) != OK:
		_fail("png save error")
		return
	print("M4 VISUAL PASS: %dx%d colors=%d image=%s (Linux Xvfb not physical device)" % [wanted.x, wanted.y, colors.size(), output])
	ui.queue_free()
	quit(0)

func _fail(message: String) -> void:
	printerr("M4 VISUAL FAIL: " + message)
	quit(1)
