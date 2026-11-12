extends RefCounted
## M3-2: pure equipment ownership, enhancement and calculated stat preview.
## Gameplay inventory persistence, item acquisition and UI are later milestones.
const Growth = preload("res://scripts/core/growth_system.gd")

const SLOTS = ["weapon", "armor", "accessory_1", "accessory_2"]
const RARITY_CAPS = {"COMMON": 5, "RARE": 10, "EPIC": 15}
const RARITY_COST_MULTIPLIERS = {"COMMON": 1, "RARE": 2, "EPIC": 4}
const STAT_KEYS = ["hp", "atk", "def"]
const SLOT_KIND = {
	"weapon": "WEAPON",
	"armor": "ARMOR",
	"accessory_1": "ACCESSORY",
	"accessory_2": "ACCESSORY"
}

## Items are templates, not instances. Any invalid or repeated template rejects
## the whole collection so no half-populated catalog can enter game state.
static func build_catalog(definitions: Array) -> Dictionary:
	if definitions.is_empty():
		return {}
	var catalog: Dictionary = {}
	for raw_entry in definitions:
		if typeof(raw_entry) != TYPE_DICTIONARY:
			return {}
		var entry: Dictionary = raw_entry
		var id: String = str(entry.get("id", ""))
		if not _valid_template(entry) or catalog.has(id):
			return {}
		catalog[id] = entry.duplicate(true)
	return catalog

static func new_item(instance_id: String, template_id: String) -> Dictionary:
	if instance_id.strip_edges().is_empty() or template_id.strip_edges().is_empty():
		return {}
	return {
		"instance_id": instance_id,
		"template_id": template_id,
		"enhance_level": 0,
		"equipped_by": "",
		"equipped_slot": ""
	}

static func new_loadout(character_id: String) -> Dictionary:
	if character_id.strip_edges().is_empty():
		return {}
	return {
		"hero_id": character_id,
		"weapon": "",
		"armor": "",
		"accessory_1": "",
		"accessory_2": ""
	}

static func enhancement_cap(rarity: String) -> int:
	return int(RARITY_CAPS.get(rarity, 0))

## Swaps the existing item back to inventory without destroying it.
## An instance equipped in another slot or on another hero cannot be reused.
static func try_equip(loadout: Dictionary, inventory: Dictionary, catalog: Dictionary, instance_id: String, slot: String) -> Dictionary:
	if not slot in SLOTS or not _valid_snapshot(loadout, inventory, catalog):
		return _gear_result(false, "invalid_state", loadout, inventory)
	if not inventory.has(instance_id):
		return _gear_result(false, "item_missing", loadout, inventory)
	var item: Dictionary = inventory[instance_id]
	var entry: Dictionary = catalog[str(item["template_id"])]
	if str(entry["slot"]) != str(SLOT_KIND[slot]):
		return _gear_result(false, "slot_mismatch", loadout, inventory)
	if str(item["equipped_by"]) != "":
		return _gear_result(false, "already_equipped", loadout, inventory)
	var existing_id: String = str(loadout[slot])
	if existing_id == instance_id:
		return _gear_result(false, "already_equipped", loadout, inventory)
	var next_loadout: Dictionary = loadout.duplicate(true)
	var next_inventory: Dictionary = inventory.duplicate(true)
	if existing_id != "":
		next_inventory[existing_id]["equipped_by"] = ""
		next_inventory[existing_id]["equipped_slot"] = ""
	next_loadout[slot] = instance_id
	next_inventory[instance_id]["equipped_by"] = str(loadout["hero_id"])
	next_inventory[instance_id]["equipped_slot"] = slot
	return _gear_result(true, "ok", next_loadout, next_inventory)

static func try_unequip(loadout: Dictionary, inventory: Dictionary, catalog: Dictionary, slot: String) -> Dictionary:
	if not slot in SLOTS or not _valid_snapshot(loadout, inventory, catalog):
		return _gear_result(false, "invalid_state", loadout, inventory)
	var item_id: String = str(loadout[slot])
	if item_id.is_empty():
		return _gear_result(false, "empty_slot", loadout, inventory)
	var next_loadout: Dictionary = loadout.duplicate(true)
	var next_inventory: Dictionary = inventory.duplicate(true)
	next_loadout[slot] = ""
	next_inventory[item_id]["equipped_by"] = ""
	next_inventory[item_id]["equipped_slot"] = ""
	return _gear_result(true, "ok", next_loadout, next_inventory)

## Deterministic enhancement: no random success rate, failure or item breakage.
## Costs are provisional M3-2 parameters until the M3-3 economy is established.
static func try_enhance(inventory: Dictionary, catalog: Dictionary, instance_id: String, wallet: Dictionary) -> Dictionary:
	if not _valid_inventory(inventory, catalog) or not _valid_enhancement_wallet(wallet):
		return _upgrade_result(false, "invalid_state", inventory, wallet, {})
	if not inventory.has(instance_id):
		return _upgrade_result(false, "item_missing", inventory, wallet, {})
	var item: Dictionary = inventory[instance_id]
	var entry: Dictionary = catalog[str(item["template_id"])]
	var level: int = int(item["enhance_level"])
	var rarity: String = str(entry["rarity"])
	if level >= enhancement_cap(rarity):
		return _upgrade_result(false, "maximum_enhancement", inventory, wallet, {})
	var cost: Dictionary = {
		"gold": 100 * (level + 1) * int(RARITY_COST_MULTIPLIERS[rarity]),
		"enhancement_stones": 1 + int(floor(float(level) / 5.0))
	}
	for key in cost:
		if int(wallet[key]) < int(cost[key]):
			return _upgrade_result(false, "insufficient_currency", inventory, wallet, cost)
	var next_inventory: Dictionary = inventory.duplicate(true)
	var next_wallet: Dictionary = wallet.duplicate(true)
	next_inventory[instance_id]["enhance_level"] = level + 1
	for key in cost:
		next_wallet[key] = int(next_wallet[key]) - int(cost[key])
	return _upgrade_result(true, "ok", next_inventory, next_wallet, cost)

## Growth formula -> sum all enhanced equipment flat bonuses -> add percentage
## bonuses by stat -> multiply once -> floor. Does not write into combat units.
static func stats_for(hero: Dictionary, character: Dictionary, loadout: Dictionary, inventory: Dictionary, catalog: Dictionary) -> Dictionary:
	if not _valid_snapshot(loadout, inventory, catalog) or str(hero.get("id", "")) != str(loadout.get("hero_id", "")):
		return {}
	var stats: Dictionary = Growth.stats_for(hero, character)
	if stats.is_empty():
		return {}
	var flat: Dictionary = {"hp": 0, "atk": 0, "def": 0}
	var percent: Dictionary = {"hp": 0.0, "atk": 0.0, "def": 0.0}
	for slot in SLOTS:
		var uid: String = str(loadout[slot])
		if uid.is_empty():
			continue
		var item: Dictionary = inventory[uid]
		var entry: Dictionary = catalog[str(item["template_id"])]
		var scale: float = 1.0 + 0.1 * float(item["enhance_level"])
		var base_flat: Dictionary = entry["flat_stats"]
		var base_percent: Dictionary = entry["percent_stats"]
		for key in STAT_KEYS:
			flat[key] = int(flat[key]) + int(floor(float(base_flat.get(key, 0)) * scale))
			percent[key] = float(percent[key]) + float(base_percent.get(key, 0.0))
	for key in STAT_KEYS:
		stats[key] = int(floor(float(int(stats[key]) + int(flat[key])) * (1.0 + float(percent[key]))))
	return stats

static func _valid_template(entry: Dictionary) -> bool:
	if typeof(entry.get("id", null)) != TYPE_STRING or str(entry.get("id", "")).strip_edges().is_empty():
		return false
	if not str(entry.get("slot", "")) in ["WEAPON", "ARMOR", "ACCESSORY"]:
		return false
	if not RARITY_CAPS.has(str(entry.get("rarity", ""))):
		return false
	if typeof(entry.get("flat_stats", null)) != TYPE_DICTIONARY or typeof(entry.get("percent_stats", null)) != TYPE_DICTIONARY:
		return false
	var flat: Dictionary = entry["flat_stats"]
	var percent: Dictionary = entry["percent_stats"]
	for key in flat:
		if not key in STAT_KEYS or typeof(flat[key]) != TYPE_INT or int(flat[key]) < 0:
			return false
	for key in percent:
		if not key in STAT_KEYS:
			return false
		if not typeof(percent[key]) in [TYPE_INT, TYPE_FLOAT]:
			return false
		if float(percent[key]) < 0.0 or float(percent[key]) > 1.0:
			return false
	return true

static func _valid_item(instance_id: String, item: Dictionary, catalog: Dictionary) -> bool:
	if instance_id.strip_edges().is_empty() or str(item.get("instance_id", "")) != instance_id:
		return false
	var template_id: String = str(item.get("template_id", ""))
	if not catalog.has(template_id):
		return false
	if typeof(catalog[template_id]) != TYPE_DICTIONARY:
		return false
	var entry: Dictionary = catalog[template_id]
	if not _valid_template(entry) or str(entry["id"]) != template_id:
		return false
	if typeof(item.get("enhance_level", null)) != TYPE_INT:
		return false
	var level: int = int(item["enhance_level"])
	if level < 0 or level > enhancement_cap(str(entry["rarity"])):
		return false
	if typeof(item.get("equipped_by", null)) != TYPE_STRING or typeof(item.get("equipped_slot", null)) != TYPE_STRING:
		return false
	var owner: String = str(item["equipped_by"])
	var slot: String = str(item["equipped_slot"])
	if owner.is_empty():
		return slot.is_empty()
	return not owner.strip_edges().is_empty() and slot in SLOTS and str(SLOT_KIND[slot]) == str(entry["slot"])

static func _valid_inventory(inventory: Dictionary, catalog: Dictionary) -> bool:
	if catalog.is_empty():
		return false
	for uid in inventory:
		if typeof(uid) != TYPE_STRING or typeof(inventory[uid]) != TYPE_DICTIONARY:
			return false
		if not _valid_item(str(uid), inventory[uid], catalog):
			return false
	return true

static func _valid_snapshot(loadout: Dictionary, inventory: Dictionary, catalog: Dictionary) -> bool:
	if not _valid_inventory(inventory, catalog):
		return false
	if typeof(loadout.get("hero_id", null)) != TYPE_STRING or str(loadout.get("hero_id", "")).strip_edges().is_empty():
		return false
	var hero_id: String = str(loadout["hero_id"])
	var assigned: Dictionary = {}
	for slot in SLOTS:
		if typeof(loadout.get(slot, null)) != TYPE_STRING:
			return false
		var uid: String = str(loadout[slot])
		if uid.is_empty():
			continue
		if assigned.has(uid) or not inventory.has(uid):
			return false
		assigned[uid] = true
		var item: Dictionary = inventory[uid]
		if str(item["equipped_by"]) != hero_id or str(item["equipped_slot"]) != slot:
			return false
	for uid in inventory:
		var item: Dictionary = inventory[uid]
		if str(item["equipped_by"]) == hero_id:
			if str(loadout.get(str(item["equipped_slot"]), "")) != str(uid):
				return false
	return true

static func _valid_enhancement_wallet(wallet: Dictionary) -> bool:
	for currency in ["gold", "enhancement_stones"]:
		if not wallet.has(currency) or typeof(wallet[currency]) != TYPE_INT or int(wallet[currency]) < 0:
			return false
	return true

static func _gear_result(ok: bool, reason: String, loadout: Dictionary, inventory: Dictionary) -> Dictionary:
	return {"ok": ok, "reason": reason, "loadout": loadout.duplicate(true), "inventory": inventory.duplicate(true)}

static func _upgrade_result(ok: bool, reason: String, inventory: Dictionary, wallet: Dictionary, cost: Dictionary) -> Dictionary:
	return {"ok": ok, "reason": reason, "inventory": inventory.duplicate(true), "wallet": wallet.duplicate(true), "cost": cost.duplicate(true)}
