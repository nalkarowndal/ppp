extends SceneTree
## Godot GLES/Compatibility renderer screenshots under Linux Xvfb,
## not a substitute for Android ARM64 or Windows physical-device interaction.
const Repo = preload("res://scripts/core/data_repository.gd")
const Gear = preload("res://scripts/core/equipment_system.gd")
const Economy = preload("res://scripts/core/economy_inventory.gd")
const Idle = preload("res://scripts/core/offline_rewards.gd")
const Store = preload("res://scripts/core/profile_store.gd")
const View = preload("res://scenes/m3_progression.tscn")
const PATH: String = "user://qa_m3_6/m3_visual_profile.json"

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var raw_size: String = OS.get_environment("M3_6_VISUAL_SIZE")
	if raw_size.is_empty():
		raw_size = "360x800"
	var parts: PackedStringArray = raw_size.split("x")
	if parts.size() != 2:
		_fail("size malformed")
		return
	var wanted: Vector2i = Vector2i(int(parts[0]), int(parts[1]))
	if wanted.x < 320 or wanted.y < 600:
		_fail("minimum viewport not met")
		return
	var phase: String = OS.get_environment("M3_6_VISUAL_PHASE")
	if phase.is_empty():
		phase = "growth"
	if not phase in ["growth", "equipment", "idle"]:
		_fail("unknown tab")
		return
	root.size = wanted
	DisplayServer.window_set_size(wanted)
	DirAccess.make_dir_recursive_absolute("user://qa_m3_6")
	for path in [PATH, PATH + ".bak", PATH + ".tmp", PATH + ".bak.tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	var catalog: Dictionary = Gear.build_catalog(Repo.load_array("res://data/equipment.json"))
	var chars: Array = Repo.load_array("res://data/characters.json")
	var fixture: Dictionary = Store.new_profile()
	for entry in chars:
		fixture["heroes"][entry["id"]] = {"id": entry["id"], "level": 1, "stars": 1}
		fixture["loadouts"][entry["id"]] = Gear.new_loadout(entry["id"])
	var granted: Dictionary = Economy.try_claim(fixture["economy_state"], catalog, "qa:visual", {"gold": 3000, "xp_crystals": 1000, "enhancement_stones": 6}, ["EQ_TRAINING_BLADE", "EQ_GUARD_PLATE", "EQ_SILVER_RING"])
	if not bool(granted.get("ok", false)):
		_fail("could not seed visual inventory")
		return
	fixture["economy_state"] = granted["state"]
	fixture["offline_checkpoint"] = Idle.new_checkpoint(1700000000, 1)
	if not bool(Store.save_profile(fixture, catalog, chars, PATH)["ok"]):
		_fail("could not save visual fixture")
		return
	var ui: Control = View.instantiate()
	ui.save_path = PATH
	root.add_child(ui)
	for i in range(8):
		await process_frame
	var tab_name: String = {"growth":"M3GrowthTab", "equipment":"M3EquipmentTab", "idle":"M3IdleTab"}[phase]
	var tab: Button = ui.find_child(tab_name, true, false)
	if tab == null:
		_fail("missing tab: " + tab_name)
		return
	tab.pressed.emit()
	for i in range(5):
		await process_frame
	# Godot stretch/canvas_items uses a logical Control coordinate space
	# that can differ from physical DisplayServer pixels. Judge the actual
	# framebuffer against wanted pixels separately below.
	var bounds: Rect2 = ui.get_global_rect()
	if bounds.size.x < 300 or bounds.size.y < 600:
		_fail("logical Control bounds too small")
		return
	for button_name in ["M3GrowthTab", "M3EquipmentTab", "M3IdleTab", "M3HeroNext"]:
		var target: Button = ui.find_child(button_name, true, false)
		if target == null or target.custom_minimum_size.y < 48:
			_fail("missing or too-small touch target: " + button_name)
			return
		if not Rect2(Vector2.ZERO, Vector2(wanted)).has_point(target.get_global_rect().get_center()):
			_fail("touch target outside viewport: " + button_name)
			return
	var image: Image = root.get_texture().get_image()
	if image.is_empty() or image.get_width() < wanted.x or image.get_height() < wanted.y:
		_fail("render capture incomplete")
		return
	var colors: Dictionary = {}
	for y in range(0, image.get_height(), maxi(1, int(image.get_height() / 20))):
		for x in range(0, image.get_width(), maxi(1, int(image.get_width() / 15))):
			colors[image.get_pixel(x, y).to_html(false)] = true
	if colors.size() < 5:
		_fail("screen almost uniform, colors=%d" % colors.size())
		return
	var folder: String = ProjectSettings.globalize_path("res://qa_artifacts")
	if DirAccess.make_dir_recursive_absolute(folder) != OK:
		_fail("cannot create artifacts directory")
		return
	var output: String = folder.path_join("m3_6_ui_%dx%d_%s.png" % [wanted.x, wanted.y, phase])
	if image.save_png(output) != OK:
		_fail("PNG save failed")
		return
	print("M3-6 VISUAL CAPTURE PASS: %dx%d %s colors=%d file=%s (Xvfb, not physical device)" % [wanted.x, wanted.y, phase, colors.size(), output])
	# Release global lifecycle model before the Xvfb screenshot process ends.
	# Production M3Session remains attached across in-game scene navigation;
	# this cleanup is strictly for an isolated one-shot QA process.
	var session_node: Node = root.get_node_or_null("M3Session")
	if session_node != null:
		session_node.call("attach", null)
	ui.queue_free()
	quit(0)

func _fail(message: String) -> void:
	push_error("M3-6 VISUAL FAIL: " + message)
	quit(1)
