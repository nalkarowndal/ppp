extends SceneTree
## M3-2 test-first equipment transactions and deterministic stat preview.
const Repo = preload("res://scripts/core/data_repository.gd")
const Growth = preload("res://scripts/core/growth_system.gd")
const Equipment = preload("res://scripts/core/equipment_system.gd")

var failures: Array[String] = []

func _initialize() -> void:
	var definitions: Array = Repo.load_array("res://data/equipment.json")
	var characters: Array = Repo.load_array("res://data/characters.json")
	_expect(definitions.size() == 6 and characters.size() == 8, "equipment and hero fixtures")
	if definitions.size() != 6 or characters.size() != 8:
		_finish()
		return
	var catalog: Dictionary = Equipment.build_catalog(definitions)
	_expect(catalog.size() == 6, "catalog accepted with unique templates")
	_expect(Equipment.build_catalog([definitions[0], definitions[0]]).is_empty(), "duplicate template IDs rejected")
	_expect(Equipment.build_catalog([{"id": "BAD", "slot": "WEAPON", "rarity": "LEGENDARY", "flat_stats": {}, "percent_stats": {}}]).is_empty(), "unsupported rarity rejected")

	var hero: Dictionary = Growth.new_hero("CHR_ARIA")
	var loadout: Dictionary = Equipment.new_loadout("CHR_ARIA")
	_expect(loadout.keys().size() == 5, "four slots plus hero ID")
	var inventory: Dictionary = {
		"w1": Equipment.new_item("w1", "EQ_TRAINING_BLADE"),
		"w2": Equipment.new_item("w2", "EQ_RANGER_BOW"),
		"a1": Equipment.new_item("a1", "EQ_GUARD_PLATE"),
		"r1": Equipment.new_item("r1", "EQ_SILVER_RING"),
		"r2": Equipment.new_item("r2", "EQ_MOON_CHARM")
	}
	_expect(Equipment.new_item("", "EQ_TRAINING_BLADE").is_empty(), "empty instance ID rejected")
	var before_inventory: Dictionary = inventory.duplicate(true)
	var before_loadout: Dictionary = loadout.duplicate(true)
	var bad_slot: Dictionary = Equipment.try_equip(loadout, inventory, catalog, "w1", "armor")
	_expect(not bool(bad_slot.get("ok", true)) and bad_slot["inventory"] == inventory, "slot mismatch prevents mutation")
	var equipped: Dictionary = Equipment.try_equip(loadout, inventory, catalog, "w1", "weapon")
	_expect(bool(equipped["ok"]) and equipped["loadout"]["weapon"] == "w1", "weapon equipped")
	_expect(inventory == before_inventory and loadout == before_loadout, "equip does not mutate original maps")
	inventory = equipped["inventory"]
	loadout = equipped["loadout"]
	for item_id in ["a1", "r1", "r2"]:
		var slot: String = "armor" if item_id == "a1" else ("accessory_1" if item_id == "r1" else "accessory_2")
		var step: Dictionary = Equipment.try_equip(loadout, inventory, catalog, item_id, slot)
		_expect(bool(step["ok"]), "equip " + item_id)
		loadout = step["loadout"]
		inventory = step["inventory"]
	_expect(not bool(Equipment.try_equip(loadout, inventory, catalog, "r1", "accessory_2")["ok"]), "duplicate item in second accessory slot blocked")
	_expect(not bool(Equipment.try_equip(Equipment.new_loadout("CHR_SERENA"), inventory, catalog, "w1", "weapon")["ok"]), "cross-hero duplicate equip blocked")
	_expect(not bool(Equipment.try_equip(loadout, inventory, catalog, "absent", "weapon")["ok"]), "missing instance blocked")

	var base_stats: Dictionary = Growth.stats_for(hero, characters[0])
	var equipped_stats: Dictionary = Equipment.stats_for(hero, characters[0], loadout, inventory, catalog)
	_expect(int(base_stats["atk"]) == 135 and int(base_stats["hp"]) == 950, "M3-1 untouched")
	_expect(int(equipped_stats.get("atk", 0)) == 168, "flat atk plus percentage atk correctly ordered")
	_expect(int(equipped_stats.get("hp", 0)) == 1196 and int(equipped_stats.get("def", 0)) == 70, "all four slots stack, hp/def values")
	_expect(float(equipped_stats.get("spd", -1.0)) == 105.0 and is_equal_approx(float(equipped_stats.get("crit", 0.0)), 0.08), "SPD and CRIT unchanged")
	_expect(int(characters[0]["base_stats"]["hp"]) == 950, "character JSON unchanged")

	var replaced: Dictionary = Equipment.try_equip(loadout, inventory, catalog, "w2", "weapon")
	_expect(bool(replaced["ok"]), "replace weapon atomically")
	_expect(str(replaced["inventory"]["w1"]["equipped_by"]) == "", "old weapon owner cleared")
	_expect(str(replaced["inventory"]["w2"]["equipped_by"]) == "CHR_ARIA", "new weapon owner recorded")
	loadout = replaced["loadout"]
	inventory = replaced["inventory"]
	var sword_and_ring: Dictionary = Equipment.stats_for(hero, characters[0], loadout, inventory, catalog)
	_expect(int(sword_and_ring.get("atk", 0)) == 181, "multiple percent boosts add then apply once")

	var not_enough: Dictionary = {"gold": 199, "enhancement_stones": 0}
	var no_upgrade: Dictionary = Equipment.try_enhance(inventory, catalog, "w2", not_enough)
	_expect(not bool(no_upgrade["ok"]) and no_upgrade["wallet"] == not_enough and no_upgrade["inventory"] == inventory, "enhance never partially spends")
	var wallet: Dictionary = {"gold": 100000, "enhancement_stones": 1000, "xp_crystals": 25, "ascension_stones": 9}
	var original_wallet: Dictionary = wallet.duplicate(true)
	var original_inventory: Dictionary = inventory.duplicate(true)
	var enhanced: Dictionary = Equipment.try_enhance(inventory, catalog, "w2", wallet)
	_expect(bool(enhanced["ok"]) and int(enhanced["inventory"]["w2"]["enhance_level"]) == 1, "upgrade rare weapon to +1")
	_expect(int(enhanced["wallet"]["gold"]) == int(wallet["gold"]) - 200 and int(enhanced["wallet"]["enhancement_stones"]) == int(wallet["enhancement_stones"]) - 1, "upgrade costs exact gold and stone")
	_expect(int(enhanced["wallet"]["xp_crystals"]) == 25, "unrelated currency preserved")
	_expect(wallet == original_wallet and inventory == original_inventory, "enhance leaves original maps unchanged")
	inventory = enhanced["inventory"]
	wallet = enhanced["wallet"]
	_expect(int(Equipment.stats_for(hero, characters[0], loadout, inventory, catalog).get("atk", 0)) == 184, "enhancement only scales gear flat stats")

	var unequipped: Dictionary = Equipment.try_unequip(loadout, inventory, catalog, "accessory_1")
	_expect(bool(unequipped["ok"]) and str(unequipped["loadout"]["accessory_1"]) == "", "ring unequipped")
	_expect(str(unequipped["inventory"]["r1"]["equipped_by"]) == "", "un-equipped ring returns to inventory")
	_expect(int(Equipment.stats_for(hero, characters[0], unequipped["loadout"], unequipped["inventory"], catalog).get("atk", 0)) == 171, "unequip removes ring flat and percent buffs")
	_expect(not bool(Equipment.try_unequip(unequipped["loadout"], unequipped["inventory"], catalog, "accessory_1")["ok"]), "empty slot does not un-equip twice")
	
	var forged: Dictionary = inventory.duplicate(true)
	forged["w2"]["equipped_slot"] = "armor"
	_expect(Equipment.stats_for(hero, characters[0], loadout, forged, catalog).is_empty(), "inconsistent ownership refuses stat preview")
	_expect(not bool(Equipment.try_equip(loadout, forged, catalog, "w1", "weapon")["ok"]), "stale ownership refuses equip")
	
	var stone_wallet: Dictionary = {"gold": 200000, "enhancement_stones": 1000}
	var common_inventory: Dictionary = {"new": Equipment.new_item("new", "EQ_TRAINING_BLADE")}
	for _i in range(5):
		var leveled: Dictionary = Equipment.try_enhance(common_inventory, catalog, "new", stone_wallet)
		_expect(bool(leveled["ok"]), "common can enhance +5")
		common_inventory = leveled["inventory"]
		stone_wallet = leveled["wallet"]
	_expect(int(common_inventory["new"]["enhance_level"]) == 5, "common +5 cap")
	var capped: Dictionary = Equipment.try_enhance(common_inventory, catalog, "new", stone_wallet)
	_expect(not bool(capped["ok"]) and capped["wallet"] == stone_wallet, "maximum enhancement no debit")
	_expect(Equipment.enhancement_cap("RARE") == 10 and Equipment.enhancement_cap("EPIC") == 15, "rarity caps 5/10/15")
	_expect(Equipment.stats_for(hero, characters[1], loadout, inventory, catalog).is_empty(), "hero ID mismatch refused")
	_finish()

func _expect(value: bool, name: String) -> void:
	if not value:
		failures.append(name)

func _finish() -> void:
	if not failures.is_empty():
		for msg in failures:
			push_error("M3-2 FAIL: " + msg)
		quit(1)
		return
	print("M3-2 EQUIPMENT PASS: four slots, atomic ownership, rarity caps, upgrades, additive bonuses, immutable data")
	quit(0)
