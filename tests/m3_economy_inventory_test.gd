extends SceneTree
## M3-3 deterministic inventory + currency receipt ledger, independent of M1 debug saves.
const Repo = preload("res://scripts/core/data_repository.gd")
const Equipment = preload("res://scripts/core/equipment_system.gd")
const Growth = preload("res://scripts/core/growth_system.gd")
const Economy = preload("res://scripts/core/economy_inventory.gd")
var failures: Array[String] = []

func _initialize() -> void:
	var catalog: Dictionary = Equipment.build_catalog(Repo.load_array("res://data/equipment.json"))
	_expect(catalog.size() == 6, "M3-2 catalog fixture present")
	if catalog.size() != 6:
		_finish()
		return
	var initial: Dictionary = Economy.new_state()
	_expect(int(initial.get("schema_version", 0)) == 1, "versioned standalone economy snapshot")
	_expect(initial["inventory"].is_empty() and int(initial["next_item_serial"]) == 1, "empty inventory and deterministic serial")
	_expect(initial["wallet"].size() == 6, "all six currency categories initialized")
	var reward: Dictionary = {"gold": 2000, "xp_crystals": 300, "ascension_stones": 5, "enhancement_stones": 5, "skill_books": 2, "crafting_materials": 9}
	var items: Array = ["EQ_TRAINING_BLADE", "EQ_TRAINING_BLADE", "EQ_SILVER_RING"]
	var claimed: Dictionary = Economy.try_claim(initial, catalog, "stage:001:first-clear", reward, items)
	_expect(bool(claimed.get("ok", false)), "stage reward granted")
	var state: Dictionary = claimed["state"]
	_expect(int(state["wallet"]["gold"]) == 2000 and int(state["wallet"]["skill_books"]) == 2, "all six currencies credited")
	_expect(state["inventory"].size() == 3 and int(state["next_item_serial"]) == 4, "three distinct item instances allocated")
	_expect(state["inventory"].has("itm_00000001") and state["inventory"].has("itm_00000002") and state["inventory"].has("itm_00000003"), "deterministic unique IDs")
	_expect(str(state["inventory"]["itm_00000002"]["template_id"]) == "EQ_TRAINING_BLADE", "duplicate templates create separate instances")
	_expect(initial["inventory"].is_empty() and int(initial["wallet"]["gold"]) == 0, "input snapshots remain immutable")
	_expect(state["seen_events"].size() == 1, "one receipt per transaction")

	var duplicate: Dictionary = Economy.try_claim(state, catalog, "stage:001:first-clear", reward, items)
	_expect(not bool(duplicate["ok"]) and duplicate["state"] == state, "same reward ID cannot pay twice")
	_expect(not bool(Economy.try_claim(state, catalog, "stage:001:first-clear", {"gold": 100000}, [])["ok"]), "reused receipt with changed payload blocked")
	_expect(not bool(Economy.try_spend(state, catalog, "stage:001:first-clear", {"gold": 1})["ok"]), "claim receipt blocks spending reuse")
	_expect(not bool(Economy.try_claim(state, catalog, "", reward, [])["ok"]), "empty receipt ID invalid")
	_expect(not bool(Economy.try_claim(state, catalog, "x", {}, [])["ok"]), "empty payout refused")
	_expect(not bool(Economy.try_claim(state, catalog, "x", {"gold": -2}, [])["ok"]), "negative payout refused")
	_expect(not bool(Economy.try_claim(state, catalog, "x", {"gold": 1.5}, [])["ok"]), "fractional payout refused")
	_expect(not bool(Economy.try_claim(state, catalog, "x", {"premium_gems": 1}, [])["ok"]), "unknown currency rejected")
	_expect(not bool(Economy.try_claim(state, catalog, "x", {"gold": 100}, ["EQ_UNKNOWN"])["ok"]), "invalid item template prevents full payout")
	_expect(state["seen_events"].size() == 1 and int(state["wallet"]["gold"]) == 2000, "rejects never mutate original")
	var equipment_ready: Dictionary = Equipment.try_equip(Equipment.new_loadout("CHR_ARIA"), state["inventory"], catalog, "itm_00000001", "weapon")
	_expect(bool(equipment_ready.get("ok", false)), "awarded equipment works with M3-2 equip engine")

	var no_money: Dictionary = Economy.try_spend(state, catalog, "shop:001", {"gold": 3000})
	_expect(not bool(no_money["ok"]) and no_money["state"] == state, "insufficient funds never partially debit or stamp receipt")
	var spent: Dictionary = Economy.try_spend(state, catalog, "shop:001", {"gold": 100, "enhancement_stones": 2})
	_expect(bool(spent["ok"]) and int(spent["state"]["wallet"]["gold"]) == 1900, "atomic multi-currency spend")
	_expect(int(spent["state"]["wallet"]["enhancement_stones"]) == 3, "second currency debited")
	_expect(not bool(Economy.try_spend(spent["state"], catalog, "shop:001", {"gold": 100})["ok"]), "spending receipt cannot repeat")
	_expect(state["wallet"]["gold"] == 2000, "spend leaves original unmodified")
	_expect(not bool(Economy.try_spend(state, catalog, "bad", {"gold": 0})["ok"]), "zero-value spend rejected")
	_expect(not bool(Economy.try_spend(state, catalog, "bad", {"gold": -1})["ok"]), "negative spend rejected")

	var hero: Dictionary = Growth.new_hero("CHR_ARIA")
	var levelled: Dictionary = Economy.try_level_up(state, catalog, "grow:aria:1-2", hero)
	_expect(bool(levelled["ok"]) and int(levelled["hero"]["level"]) == 2, "M3-1 level-up through ledger")
	_expect(int(levelled["state"]["wallet"]["xp_crystals"]) == 180 and int(levelled["state"]["wallet"]["gold"]) == 1928, "growth spent once with correct original costs")
	_expect(not bool(Economy.try_level_up(levelled["state"], catalog, "grow:aria:1-2", hero)["ok"]), "repeated growth receipt blocked")
	_expect(int(hero["level"]) == 1, "original hero preserved")
	var enhanced: Dictionary = Economy.try_enhance(state, catalog, "enhance:item1:level1", "itm_00000001")
	_expect(bool(enhanced["ok"]) and int(enhanced["state"]["inventory"]["itm_00000001"]["enhance_level"]) == 1, "M3-2 gear enhanced through ledger")
	_expect(int(enhanced["state"]["wallet"]["gold"]) == 1900 and int(enhanced["state"]["wallet"]["enhancement_stones"]) == 4, "gear costs accounted once")
	_expect(not bool(Economy.try_enhance(enhanced["state"], catalog, "enhance:item1:level1", "itm_00000001")["ok"]), "gear enhancement receipt blocks double charge")
	var cap_hero: Dictionary = {"id": "CHR_ARIA", "level": 20, "stars": 1}
	var promoted: Dictionary = Economy.try_ascend(state, catalog, "ascend:aria:1-2", cap_hero)
	_expect(bool(promoted["ok"]) and int(promoted["hero"]["stars"]) == 2, "ascension through receipt ledger")
	_expect(int(promoted["state"]["wallet"]["ascension_stones"]) == 0 and int(promoted["state"]["wallet"]["gold"]) == 1000, "promotion debits single ledger receipt")

	var next_reward: Dictionary = Economy.try_claim(state, catalog, "stage:002:repeat", {"gold": 7}, ["EQ_GUARD_PLATE"])
	_expect(bool(next_reward["ok"]) and next_reward["state"]["inventory"].has("itm_00000004"), "distinct reward emits next unique item ID")
	var roundtrip: Variant = JSON.parse_string(JSON.stringify(enhanced["state"]))
	_expect(typeof(roundtrip) == TYPE_DICTIONARY, "JSON serialization yields dictionary")
	if typeof(roundtrip) == TYPE_DICTIONARY:
		var loaded: Dictionary = Economy.normalize_state(roundtrip, catalog)
		_expect(not loaded.is_empty() and int(loaded["wallet"]["gold"]) == 1900, "Godot JSON float integers normalized safely")
		_expect(typeof(loaded["inventory"]["itm_00000001"]["enhance_level"]) == TYPE_INT, "M3-2 equipment level restores as int")
		_expect(not bool(Economy.try_claim(loaded, catalog, "stage:001:first-clear", reward, items)["ok"]), "replayed first-clear receipt blocked after JSON roundtrip")
		_expect(not bool(Economy.try_enhance(loaded, catalog, "enhance:item1:level1", "itm_00000001")["ok"]), "replayed enhancement blocked after JSON roundtrip")

	var almost_full: Dictionary = Economy.new_state()
	almost_full["wallet"]["gold"] = 2000000000
	_expect(not bool(Economy.try_claim(almost_full, catalog, "over", {"gold": 1}, [])["ok"]), "currency overflow blocked")
	var collide: Dictionary = Economy.new_state()
	collide["inventory"]["itm_00000001"] = Equipment.new_item("itm_00000001", "EQ_TRAINING_BLADE")
	_expect(not bool(Economy.try_claim(collide, catalog, "collision", {}, ["EQ_TRAINING_BLADE"])["ok"]), "existing unique item ID collision blocks payout")
	var invalid: Dictionary = Economy.new_state()
	invalid["wallet"]["gold"] = -10
	_expect(Economy.normalize_state(invalid, catalog).is_empty(), "invalid wallet rejected at boundary")
	var arbitrary: Dictionary = Economy.new_state()
	arbitrary["seen_events"]["already"] = {"kind": "external"}
	_expect(Economy.normalize_state(arbitrary, catalog).is_empty(), "receipt spoofing rejected")
	_finish()

func _expect(condition: bool, title: String) -> void:
	if not condition:
		failures.append(title)

func _finish() -> void:
	if failures.is_empty():
		print("M3-3 ECONOMY PASS: idempotent rewards and spends, distinct equipment, growth integration, JSON restore and overflow guards")
		quit(0)
		return
	for title in failures:
		push_error("M3-3 FAIL: " + title)
	quit(1)
