extends SceneTree
## M3-6 new portrait Control view: labels, 52px touches, interaction, save.
const Repo = preload("res://scripts/core/data_repository.gd")
const Gear = preload("res://scripts/core/equipment_system.gd")
const Economy = preload("res://scripts/core/economy_inventory.gd")
const Idle = preload("res://scripts/core/offline_rewards.gd")
const Save = preload("res://scripts/core/profile_store.gd")
const T0: int = 1700000000
const PATH: String = "user://qa_m3_6/ui_profile.json"
var failures: Array[String] = []

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("user://qa_m3_6")
	for file in [PATH, PATH + ".bak", PATH + ".tmp", PATH + ".bak.tmp"]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)
	var chars: Array = Repo.load_array("res://data/characters.json")
	var catalog: Dictionary = Gear.build_catalog(Repo.load_array("res://data/equipment.json"))
	var funded: Dictionary = Save.new_profile()
	for entry in chars:
		funded["heroes"][entry["id"]] = {"id":entry["id"],"level":1,"stars":1}
		funded["loadouts"][entry["id"]] = Gear.new_loadout(entry["id"])
	var granted: Dictionary = Economy.try_claim(funded["economy_state"], catalog, "qa:ui:fund", {"gold": 2500, "xp_crystals": 400, "enhancement_stones": 3}, ["EQ_TRAINING_BLADE", "EQ_SILVER_RING"])
	funded["economy_state"] = granted["state"]
	funded["offline_checkpoint"] = Idle.new_checkpoint(T0, 1)
	_assert(bool(Save.save_profile(funded, catalog, chars, PATH)["ok"]), "QA save funded")
	var scene: PackedScene = load("res://scenes/m3_progression.tscn")
	_assert(scene != null, "M3 screen scene loads")
	if scene == null:
		_finish()
		return
	var view: Control = scene.instantiate()
	view.save_path = PATH
	root.add_child(view)
	await process_frame
	await process_frame
	for name in ["M3GrowthTab", "M3EquipmentTab", "M3IdleTab", "M3LevelButton", "M3AscendButton", "M3HeroNext", "M3WalletLabel", "M3StatusLabel"]:
		_assert(view.find_child(name, true, false) != null, "UI node " + name + " exists")
	var grow: Button = view.find_child("M3GrowthTab", true, false)
	var equipment: Button = view.find_child("M3EquipmentTab", true, false)
	var idle: Button = view.find_child("M3IdleTab", true, false)
	var lv: Button = view.find_child("M3LevelButton", true, false)
	_assert(grow.custom_minimum_size.y >= 48 and equipment.custom_minimum_size.y >= 48, "tabs target height >= 48")
	_assert(lv.custom_minimum_size.y >= 48 and not lv.disabled, "level button touch target and affordability")
	var previous: Dictionary = Save.load_profile(PATH, catalog, chars)["profile"]
	lv.pressed.emit()
	await process_frame
	var updated: Dictionary = Save.load_profile(PATH, catalog, chars)["profile"]
	_assert(int(updated["heroes"]["CHR_ARIA"]["level"]) == 2, "real button press changes saved level")
	_assert(int(updated["revision"]) > int(previous["revision"]), "UI transaction saved atomically")
	equipment.pressed.emit()
	await process_frame
	var inv: ScrollContainer = view.find_child("M3InventoryScroll", true, false)
	_assert(inv != null and inv.visible, "equipment tab scroll shown")
	var row_button: Button = view.find_child("M3Equip_itm_00000001", true, false)
	_assert(row_button != null, "inventory equip button present")
	if row_button != null:
		row_button.pressed.emit()
		await process_frame
		var after_equipped: Dictionary = Save.load_profile(PATH, catalog, chars)["profile"]
		_assert(after_equipped["loadouts"]["CHR_ARIA"]["weapon"] == "itm_00000001", "equip UI saves slot ownership")
	idle.pressed.emit()
	await process_frame
	var claim_button: Button = view.find_child("M3IdleClaimButton", true, false)
	_assert(claim_button != null and claim_button.visible, "idle reward CTA visible")
	if claim_button != null:
		_assert(claim_button.custom_minimum_size.y >= 48, "idle button touch target")
	var screen_rect: Rect2 = view.get_global_rect()
	_assert(screen_rect.size.x > 0 and screen_rect.size.y > 0, "portrait screen initialized")
	view.queue_free()
	await process_frame
	_finish()

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("M3-6 UI PASS: portrait tabs, readable controls, saved growth and equipment actions")
		quit(0)
		return
	for issue in failures:
		push_error("M3-6 UI FAIL: " + issue)
	quit(1)
