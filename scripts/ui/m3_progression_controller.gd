extends RefCounted
## M3-6 transactional presentation model. All changes are derived from
## validated M3-1..M3-5 APIs and committed to the profile before publishing.
## The UI does NOT issue currency, equipment, stage clears or free levels.
const Repo = preload("res://scripts/core/data_repository.gd")
const Growth = preload("res://scripts/core/growth_system.gd")
const Gear = preload("res://scripts/core/equipment_system.gd")
const Economy = preload("res://scripts/core/economy_inventory.gd")
const Idle = preload("res://scripts/core/offline_rewards.gd")
const Store = preload("res://scripts/core/profile_store.gd")

var _path: String = Store.SAVE_PATH
var _characters: Array = []
var _catalog: Dictionary = {}
var _balance: Dictionary = {}
var _profile: Dictionary = {}
var _selected_id: String = "CHR_ARIA"

func initialize(profile_path: String = Store.SAVE_PATH) -> Dictionary:
	_path = profile_path
	_characters = Repo.load_array("res://data/characters.json")
	_catalog = Gear.build_catalog(Repo.load_array("res://data/equipment.json"))
	_balance = Repo.load_dictionary("res://data/balance_config.json")
	if _characters.size() != 8 or _catalog.is_empty() or _balance.is_empty():
		return _result(false, "catalog_missing")
	var loaded: Dictionary = Store.load_profile(_path, _catalog, _characters)
	if not bool(loaded.get("ok", false)):
		if str(loaded.get("reason", "")) != "not_found":
			return _result(false, str(loaded.get("reason", "invalid_save")))
		var created: Dictionary = Store.new_profile()
		for raw in _characters:
			var id: String = str(raw["id"])
			created["heroes"][id] = Growth.new_hero(id)
			created["loadouts"][id] = Gear.new_loadout(id)
		var saved: Dictionary = Store.save_profile(created, _catalog, _characters, _path)
		if not bool(saved["ok"]):
			return _result(false, str(saved["reason"]))
		_profile = saved["profile"]
	else:
		var restored: Dictionary = loaded["profile"]
		var amended: Dictionary = restored.duplicate(true)
		for raw in _characters:
			var id: String = str(raw["id"])
			if not amended["heroes"].has(id):
				amended["heroes"][id] = Growth.new_hero(id)
				amended["loadouts"][id] = Gear.new_loadout(id)
		if bool(loaded.get("migrated", false)) or amended != restored:
			var fixed: Dictionary = Store.save_profile(amended, _catalog, _characters, _path)
			if not bool(fixed["ok"]):
				return _result(false, str(fixed["reason"]))
			_profile = fixed["profile"]
		else:
			_profile = restored
	if not _profile["heroes"].has(_selected_id):
		_selected_id = str(_characters[0]["id"])
	return _result(true, "ok")

func snapshot() -> Dictionary:
	return _profile.duplicate(true)

func character_definitions() -> Array:
	return _characters.duplicate(true)

func equipment_catalog() -> Dictionary:
	return _catalog.duplicate(true)

func selected_hero_id() -> String:
	return _selected_id

func selected_character() -> Dictionary:
	for raw in _characters:
		if str(raw.get("id", "")) == _selected_id:
			return raw.duplicate(true)
	return {}

func selected_hero() -> Dictionary:
	if _profile.is_empty() or not _profile["heroes"].has(_selected_id):
		return {}
	return _profile["heroes"][_selected_id].duplicate(true)

func selected_stats() -> Dictionary:
	if _profile.is_empty() or not _profile["loadouts"].has(_selected_id):
		return {}
	return Gear.stats_for(_profile["heroes"][_selected_id], selected_character(), _profile["loadouts"][_selected_id], _profile["economy_state"]["inventory"], _catalog)

func select_hero(hero_id: String) -> Dictionary:
	if _profile.is_empty() or not _profile["heroes"].has(hero_id):
		return _result(false, "unknown_hero")
	_selected_id = hero_id
	return _result(true, "ok")

func level_selected() -> Dictionary:
	if _profile.is_empty():
		return _result(false, "not_initialized")
	var op: Dictionary = Economy.try_level_up(_profile["economy_state"], _catalog, _receipt("level"), selected_hero())
	if not bool(op.get("ok", false)):
		return _result(false, str(op.get("reason", "invalid_growth")))
	var updated: Dictionary = _profile.duplicate(true)
	updated["heroes"][_selected_id] = op["hero"]
	updated["economy_state"] = op["state"]
	return _persist(updated)

func ascend_selected() -> Dictionary:
	if _profile.is_empty():
		return _result(false, "not_initialized")
	var op: Dictionary = Economy.try_ascend(_profile["economy_state"], _catalog, _receipt("ascend"), selected_hero())
	if not bool(op.get("ok", false)):
		return _result(false, str(op.get("reason", "invalid_growth")))
	var updated: Dictionary = _profile.duplicate(true)
	updated["heroes"][_selected_id] = op["hero"]
	updated["economy_state"] = op["state"]
	return _persist(updated)

func equip_item(instance_id: String, slot: String) -> Dictionary:
	if _profile.is_empty():
		return _result(false, "not_initialized")
	var old: Dictionary = _profile["loadouts"][_selected_id]
	var op: Dictionary = Gear.try_equip(old, _profile["economy_state"]["inventory"], _catalog, instance_id, slot)
	if not bool(op.get("ok", false)):
		return _result(false, str(op.get("reason", "invalid_equipment")))
	var updated: Dictionary = _profile.duplicate(true)
	updated["loadouts"][_selected_id] = op["loadout"]
	updated["economy_state"]["inventory"] = op["inventory"]
	return _persist(updated)

func unequip_slot(slot: String) -> Dictionary:
	if _profile.is_empty():
		return _result(false, "not_initialized")
	var op: Dictionary = Gear.try_unequip(_profile["loadouts"][_selected_id], _profile["economy_state"]["inventory"], _catalog, slot)
	if not bool(op.get("ok", false)):
		return _result(false, str(op.get("reason", "invalid_equipment")))
	var updated: Dictionary = _profile.duplicate(true)
	updated["loadouts"][_selected_id] = op["loadout"]
	updated["economy_state"]["inventory"] = op["inventory"]
	return _persist(updated)

func enhance_item(instance_id: String) -> Dictionary:
	if _profile.is_empty():
		return _result(false, "not_initialized")
	var op: Dictionary = Economy.try_enhance(_profile["economy_state"], _catalog, _receipt("enhance:" + instance_id), instance_id)
	if not bool(op.get("ok", false)):
		return _result(false, str(op.get("reason", "invalid_enhancement")))
	var updated: Dictionary = _profile.duplicate(true)
	updated["economy_state"] = op["state"]
	return _persist(updated)

func preview_idle(now_unix: Variant) -> Dictionary:
	if _profile.is_empty():
		return {"ok": false, "reason": "not_initialized"}
	if _profile["offline_checkpoint"].is_empty():
		return {"ok": false, "reason": "no_checkpoint"}
	return Idle.preview(_profile["offline_checkpoint"], now_unix, _balance)

## Call only when user explicitly accepts an available reward.
func claim_idle(now_unix: Variant) -> Dictionary:
	if _profile.is_empty():
		return _result(false, "not_initialized")
	var payout: Dictionary = Store.commit_offline_claim(_path, _catalog, _characters, now_unix, _balance)
	if not bool(payout.get("ok", false)):
		return _result(false, str(payout.get("reason", "invalid_claim")))
	_profile = payout["profile"]
	return _result(true, "ok")

## OS pause/close notification (not a focus change). Avoid duplicating a
## receipt key for a checkpoint recorded in the same UTC second.
func mark_background(exit_unix: Variant) -> Dictionary:
	if _profile.is_empty():
		return _result(false, "not_initialized")
	if typeof(exit_unix) != TYPE_INT and typeof(exit_unix) != TYPE_FLOAT:
		return _result(false, "invalid_time")
	if not _profile["offline_checkpoint"].is_empty():
		if int(exit_unix) <= int(_profile["offline_checkpoint"]["last_exit_unix"]):
			return _result(false, "unchanged_checkpoint")
	var checkpoint: Dictionary = Store.commit_logout_checkpoint(
		_path, _catalog, _characters, exit_unix, int(_profile["highest_cleared_stage"])
	)
	if not bool(checkpoint.get("ok", false)):
		return _result(false, str(checkpoint.get("reason", "invalid_checkpoint")))
	_profile = checkpoint["profile"]
	return _result(true, "ok")

func _receipt(action: String) -> String:
	return "ui:%s:%s:%d" % [action, _selected_id, int(_profile["revision"])]

func _persist(draft: Dictionary) -> Dictionary:
	var saved: Dictionary = Store.save_profile(draft, _catalog, _characters, _path)
	if not bool(saved.get("ok", false)):
		return _result(false, str(saved.get("reason", "save_failed")))
	_profile = saved["profile"]
	return _result(true, "ok")

func _result(ok: bool, reason: String) -> Dictionary:
	return {"ok": ok, "reason": reason, "profile": _profile.duplicate(true)}
