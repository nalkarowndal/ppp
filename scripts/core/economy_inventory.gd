extends RefCounted
## M3-3 prototype economy: immutable currency/item transactions with monotonic
## item IDs and a permanent receipt set. No persistence or trustworthy reward
## authority is implemented here: M3-5 must save state and receipts atomically.
const Equipment = preload("res://scripts/core/equipment_system.gd")
const Growth = preload("res://scripts/core/growth_system.gd")

const SCHEMA_VERSION: int = 1
const MAX_BALANCE: int = 2000000000
const MAX_INVENTORY: int = 200
const MAX_SERIAL: int = 1999999999
const CURRENCIES = ["gold", "xp_crystals", "ascension_stones", "enhancement_stones", "skill_books", "crafting_materials"]
const EVENT_KINDS = ["claim", "spend", "level_up", "ascend", "enhance"]

static func new_state() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"wallet": {
			"gold": 0, "xp_crystals": 0, "ascension_stones": 0,
			"enhancement_stones": 0, "skill_books": 0, "crafting_materials": 0
		},
		"inventory": {},
		"seen_events": {},
		"next_item_serial": 1
	}

## M3-5 will provide durable storage. This makes a JSON-parsed state safe for
## immediate M3-1/2 use: JSON numeric values become floating-point Variants.
## Invalid or forged shapes are rejected instead of silently truncating values.
static func normalize_state(raw: Dictionary, catalog: Dictionary) -> Dictionary:
	if not _valid_integer(raw.get("schema_version", null), 1, 1):
		return {}
	var raw_wallet: Variant = raw.get("wallet", null)
	var raw_inventory: Variant = raw.get("inventory", null)
	var raw_events: Variant = raw.get("seen_events", null)
	if typeof(raw_wallet) != TYPE_DICTIONARY or typeof(raw_inventory) != TYPE_DICTIONARY or typeof(raw_events) != TYPE_DICTIONARY:
		return {}
	if not _valid_integer(raw.get("next_item_serial", null), 1, MAX_SERIAL):
		return {}
	var wallet: Dictionary = raw_wallet
	if wallet.size() != CURRENCIES.size():
		return {}
	var normalized_wallet: Dictionary = {}
	for currency in CURRENCIES:
		if not _valid_integer(wallet.get(currency, null), 0, MAX_BALANCE):
			return {}
		normalized_wallet[currency] = int(wallet[currency])

	var inventory: Dictionary = raw_inventory
	if inventory.size() > MAX_INVENTORY:
		return {}
	var normalized_inventory: Dictionary = {}
	for uid in inventory:
		if typeof(uid) != TYPE_STRING or typeof(inventory[uid]) != TYPE_DICTIONARY:
			return {}
		var item: Dictionary = inventory[uid].duplicate(true)
		if not _valid_integer(item.get("enhance_level", null), 0, 15):
			return {}
		item["enhance_level"] = int(item["enhance_level"])
		normalized_inventory[uid] = item
	if not Equipment.validate_inventory(normalized_inventory, catalog):
		return {}

	var seen: Dictionary = raw_events
	var normalized_events: Dictionary = {}
	for event_id in seen:
		if typeof(event_id) != TYPE_STRING or not _valid_event_id(str(event_id)):
			return {}
		if typeof(seen[event_id]) != TYPE_DICTIONARY:
			return {}
		var receipt: Dictionary = seen[event_id]
		if receipt.size() != 1 or not str(receipt.get("kind", "")) in EVENT_KINDS:
			return {}
		normalized_events[event_id] = {"kind": str(receipt["kind"])}
	return {
		"schema_version": SCHEMA_VERSION,
		"wallet": normalized_wallet,
		"inventory": normalized_inventory,
		"seen_events": normalized_events,
		"next_item_serial": int(raw["next_item_serial"])
	}

## Only trusted game logic should issue unique event IDs and rewards.
## Replaying the same event ID never pays again, even if the payload changes.
static func try_claim(state: Dictionary, catalog: Dictionary, event_id: String, rewards: Dictionary, templates: Array) -> Dictionary:
	var next: Dictionary = normalize_state(state, catalog)
	if next.is_empty():
		return _result(false, "invalid_state", state)
	var guard: String = _event_guard(next, event_id)
	if guard != "ok":
		return _result(false, guard, state)
	if not _valid_amounts(rewards) or (rewards.is_empty() and templates.is_empty()):
		return _result(false, "invalid_reward", state)
	if templates.size() > MAX_INVENTORY - int(next["inventory"].size()):
		return _result(false, "inventory_full", state)
	if templates.size() > MAX_SERIAL - int(next["next_item_serial"]):
		return _result(false, "serial_exhausted", state)
	for currency in rewards:
		if int(rewards[currency]) > MAX_BALANCE - int(next["wallet"][currency]):
			return _result(false, "currency_overflow", state)
	for template_id in templates:
		if typeof(template_id) != TYPE_STRING or str(template_id).strip_edges().is_empty() or not catalog.has(str(template_id)):
			return _result(false, "unknown_equipment", state)
	for template_id in templates:
		var serial: int = int(next["next_item_serial"])
		var uid: String = "itm_%08d" % serial
		if next["inventory"].has(uid):
			return _result(false, "instance_collision", state)
		next["inventory"][uid] = Equipment.new_item(uid, str(template_id))
		next["next_item_serial"] = serial + 1
	for currency in rewards:
		next["wallet"][currency] = int(next["wallet"][currency]) + int(rewards[currency])
	next["seen_events"][event_id] = {"kind": "claim"}
	return _result(true, "ok", next)

## An explicit purchase or sink, not an authorization check. Consumers must
## choose stable transaction IDs and commit the returned snapshot atomically.
static func try_spend(state: Dictionary, catalog: Dictionary, event_id: String, costs: Dictionary) -> Dictionary:
	var next: Dictionary = normalize_state(state, catalog)
	if next.is_empty():
		return _result(false, "invalid_state", state)
	var guard: String = _event_guard(next, event_id)
	if guard != "ok":
		return _result(false, guard, state)
	if not _valid_amounts(costs) or costs.is_empty():
		return _result(false, "invalid_cost", state)
	for currency in costs:
		if int(next["wallet"][currency]) < int(costs[currency]):
			return _result(false, "insufficient_currency", state)
	for currency in costs:
		next["wallet"][currency] = int(next["wallet"][currency]) - int(costs[currency])
	next["seen_events"][event_id] = {"kind": "spend"}
	return _result(true, "ok", next)

## Integration adapters: the original M3-1/2 formulas remain authoritative.
## The event ID also makes repeated growth/enhancement calls no-ops.
static func try_level_up(state: Dictionary, catalog: Dictionary, event_id: String, hero: Dictionary) -> Dictionary:
	var next: Dictionary = normalize_state(state, catalog)
	var guard: String = _event_guard(next, event_id) if not next.is_empty() else "invalid_state"
	if guard != "ok":
		return _hero_result(false, guard, state, hero)
	var operation: Dictionary = Growth.try_level_up(hero, next["wallet"])
	if not bool(operation.get("ok", false)):
		return _hero_result(false, str(operation.get("reason", "invalid_growth")), state, hero)
	next["wallet"] = operation["wallet"]
	next["seen_events"][event_id] = {"kind": "level_up"}
	return _hero_result(true, "ok", next, operation["hero"])

static func try_ascend(state: Dictionary, catalog: Dictionary, event_id: String, hero: Dictionary) -> Dictionary:
	var next: Dictionary = normalize_state(state, catalog)
	var guard: String = _event_guard(next, event_id) if not next.is_empty() else "invalid_state"
	if guard != "ok":
		return _hero_result(false, guard, state, hero)
	var operation: Dictionary = Growth.try_ascend(hero, next["wallet"])
	if not bool(operation.get("ok", false)):
		return _hero_result(false, str(operation.get("reason", "invalid_growth")), state, hero)
	next["wallet"] = operation["wallet"]
	next["seen_events"][event_id] = {"kind": "ascend"}
	return _hero_result(true, "ok", next, operation["hero"])

static func try_enhance(state: Dictionary, catalog: Dictionary, event_id: String, item_id: String) -> Dictionary:
	var next: Dictionary = normalize_state(state, catalog)
	var guard: String = _event_guard(next, event_id) if not next.is_empty() else "invalid_state"
	if guard != "ok":
		return _result(false, guard, state)
	var operation: Dictionary = Equipment.try_enhance(next["inventory"], catalog, item_id, next["wallet"])
	if not bool(operation.get("ok", false)):
		return _result(false, str(operation.get("reason", "invalid_enhancement")), state)
	next["inventory"] = operation["inventory"]
	next["wallet"] = operation["wallet"]
	next["seen_events"][event_id] = {"kind": "enhance"}
	return _result(true, "ok", next)

static func _event_guard(state: Dictionary, event_id: String) -> String:
	if not _valid_event_id(event_id):
		return "invalid_event_id"
	if state["seen_events"].has(event_id):
		return "duplicate_event"
	return "ok"

static func _valid_event_id(event_id: String) -> bool:
	return not event_id.is_empty() and event_id.length() <= 128 and event_id == event_id.strip_edges()

static func _valid_amounts(amounts: Dictionary) -> bool:
	for currency in amounts:
		if typeof(currency) != TYPE_STRING or not str(currency) in CURRENCIES:
			return false
		if not _valid_integer(amounts[currency], 1, MAX_BALANCE):
			return false
	return true

static func _valid_integer(value: Variant, minimum: int, maximum: int) -> bool:
	var kind: int = typeof(value)
	if kind != TYPE_INT and kind != TYPE_FLOAT:
		return false
	var number: float = float(value)
	if not is_finite(number) or number < float(minimum) or number > float(maximum):
		return false
	return number == floor(number)

static func _result(ok: bool, reason: String, state: Dictionary) -> Dictionary:
	return {"ok": ok, "reason": reason, "state": state.duplicate(true)}

static func _hero_result(ok: bool, reason: String, state: Dictionary, hero: Dictionary) -> Dictionary:
	var result: Dictionary = _result(ok, reason, state)
	result["hero"] = hero.duplicate(true)
	return result
