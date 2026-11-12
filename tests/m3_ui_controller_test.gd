extends SceneTree
## M3-6 core UI controller: production store, no grants from screen, real transactions.
const Repo = preload("res://scripts/core/data_repository.gd")
const Gear = preload("res://scripts/core/equipment_system.gd")
const Growth = preload("res://scripts/core/growth_system.gd")
const Economy = preload("res://scripts/core/economy_inventory.gd")
const Idle = preload("res://scripts/core/offline_rewards.gd")
const Store = preload("res://scripts/core/profile_store.gd")
const Model = preload("res://scripts/ui/m3_progression_controller.gd")
const T0: int = 1700000000
const PATH: String = "user://qa_m3_6/controller_profile.json"
var failures: Array[String] = []

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("user://qa_m3_6")
	for file in [PATH, PATH + ".bak", PATH + ".tmp", PATH + ".bak.tmp"]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)
	var model := Model.new()
	var started: Dictionary = model.initialize(PATH)
	_assert(bool(started.get("ok", false)), "create empty M3-6 production profile")
	if not bool(started.get("ok", false)):
		_finish()
		return
	var empty: Dictionary = model.snapshot()
	_assert(empty["heroes"].size() == 8 and empty["loadouts"].size() == 8, "all eight known characters available")
	_assert(empty["economy_state"]["inventory"].is_empty(), "no free inventory grants via UI")
	_assert(int(empty["economy_state"]["wallet"]["gold"]) == 0, "no free currency grants via UI")
	_assert(FileAccess.file_exists(PATH), "profile written to user directory")
	_assert(bool(model.select_hero("CHR_ARIA")["ok"]), "select known hero")
	_assert(not bool(model.select_hero("CHR_FAKE")["ok"]), "reject unknown hero")
	_assert(not bool(model.level_selected()["ok"]), "cannot level without currency")
	_assert(model.snapshot() == empty, "failed level never mutates saved data")

	var catalog: Dictionary = Gear.build_catalog(Repo.load_array("res://data/equipment.json"))
	var characters: Array = Repo.load_array("res://data/characters.json")
	var funded: Dictionary = empty.duplicate(true)
	var grant: Dictionary = Economy.try_claim(funded["economy_state"], catalog, "qa:startup-rewards", {"gold": 10000, "xp_crystals": 1000, "enhancement_stones": 10, "ascension_stones": 10}, ["EQ_TRAINING_BLADE", "EQ_SILVER_RING", "EQ_RANGER_BOW"])
	_assert(bool(grant.get("ok", false)), "fixture grant created by trusted QA, not UI")
	funded["economy_state"] = grant["state"]
	funded["offline_checkpoint"] = Idle.new_checkpoint(T0, 1)
	var saved: Dictionary = Store.save_profile(funded, catalog, characters, PATH)
	_assert(bool(saved["ok"]), "QA-funded profile persisted")
	_assert(bool(model.initialize(PATH)["ok"]), "reopen a populated profile")
	_assert(model.snapshot()["heroes"].size() == 8, "reopen preserves eight hero slots")
	model.select_hero("CHR_ARIA")
	var original: Dictionary = model.snapshot()
	var levelled: Dictionary = model.level_selected()
	_assert(bool(levelled["ok"]) and int(model.selected_hero()["level"]) == 2, "level button executes M3-1 paid growth")
	_assert(int(model.snapshot()["economy_state"]["wallet"]["gold"]) < int(original["economy_state"]["wallet"]["gold"]), "growth consumes gold")
	_assert(not bool(model.ascend_selected()["ok"]), "ascension at level two not allowed")
	var equipped: Dictionary = model.equip_item("itm_00000001", "weapon")
	_assert(bool(equipped["ok"]), "weapon equips to selected hero")
	_assert(model.snapshot()["loadouts"]["CHR_ARIA"]["weapon"] == "itm_00000001", "equipped weapon saved")
	var base_stats: Dictionary = model.selected_stats()
	_assert(int(base_stats.get("atk", 0)) > 135, "equipped stats include weapon")
	var enhanced: Dictionary = model.enhance_item("itm_00000001")
	_assert(bool(enhanced["ok"]), "enhance item debits economic ledger")
	_assert(int(model.snapshot()["economy_state"]["inventory"]["itm_00000001"]["enhance_level"]) == 1, "enhancement level persisted")
	_assert(not bool(model.equip_item("itm_00000002", "armor")["ok"]), "wrong slot rejected")
	var ring: Dictionary = model.equip_item("itm_00000002", "accessory_1")
	_assert(bool(ring["ok"]), "first accessory slot equipped")
	_assert(not bool(model.equip_item("itm_00000002", "accessory_2")["ok"]), "equipped instance cannot duplicate")
	var unequipped: Dictionary = model.unequip_slot("weapon")
	_assert(bool(unequipped["ok"]) and model.snapshot()["loadouts"]["CHR_ARIA"]["weapon"] == "", "unequip returns to inventory")
	var backup: Dictionary = model.snapshot()
	var error: Dictionary = model.equip_item("nonexistent", "weapon")
	_assert(not bool(error["ok"]) and model.snapshot() == backup, "invalid gear cannot mutate saved profile")

	var preview: Dictionary = model.preview_idle(T0 + 3600)
	_assert(bool(preview["ok"]) and int(preview["rewards"]["gold"]) == 160, "offline panel previews true 8h/80% policy")
	var paid: Dictionary = model.claim_idle(T0 + 3600)
	_assert(bool(paid["ok"]) and model.snapshot()["economy_state"]["seen_events"].has("offline:1700000000"), "claim panel persists offline receipt")
	_assert(not bool(model.claim_idle(T0 + 3600)["ok"]), "claim cannot repeat")
	var separate := Model.new()
	_assert(bool(separate.initialize(PATH)["ok"]), "separate controller reloads save after transactions")
	_assert(int(separate.snapshot()["heroes"]["CHR_ARIA"]["level"]) == 2, "reopened hero growth preserved")
	_assert(int(separate.snapshot()["economy_state"]["inventory"]["itm_00000001"]["enhance_level"]) == 1, "reopened enhancement preserved")
	_assert(int(separate.snapshot()["economy_state"]["wallet"]["gold"]) >= 160, "reopened wallet preserved")
	_assert(not bool(separate.claim_idle(T0 + 3600)["ok"]), "persisted receipt prevents duplicate after restart")
	var after_resume: Dictionary = separate.mark_background(T0 + 3700)
	_assert(bool(after_resume["ok"]), "real lifecycle background saves fresh checkpoint")
	_assert(int(separate.snapshot()["offline_checkpoint"]["last_exit_unix"]) == T0 + 3700, "new exit timestamp on background")
	var after_foreground: Dictionary = separate.preview_idle(T0 + 7300)
	_assert(bool(after_foreground["ok"]) and int(after_foreground["rewards"]["gold"]) == 160, "resume preview uses fresh checkpoint")
	_assert(bool(separate.claim_idle(T0 + 7300)["ok"]), "second session reward can be claimed once")
	var bad_path := Model.new()
	_assert(not bool(bad_path.initialize("res://bad.json")["ok"]), "unsafe path cannot be initialized")
	_finish()

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("M3-6 CONTROLLER PASS: eight heroes, level/gear/enhance, idle reward, lifecycle and save replay")
		quit(0)
		return
	for issue in failures:
		push_error("M3-6 FAIL: " + issue)
	quit(1)
