extends RefCounted
## M4 first ten stages: battle authority, first-clear/replay receipts and
## M3 atomic profile persistence. This is an offline vertical slice, NOT
## network-authoritative progression or a finished balance system.
const Repo = preload("res://scripts/core/data_repository.gd")
const Battle = preload("res://scripts/combat/auto_battle_core.gd")
const Gear = preload("res://scripts/core/equipment_system.gd")
const Economy = preload("res://scripts/core/economy_inventory.gd")
const Store = preload("res://scripts/core/profile_store.gd")
const M3Model = preload("res://scripts/ui/m3_progression_controller.gd")

const STAGE_COUNT: int = 10
const FIRST_CLEAR_ITEMS: Dictionary = {
	1: "EQ_TRAINING_BLADE", 3: "EQ_GUARD_PLATE",
	5: "EQ_SILVER_RING", 7: "EQ_RANGER_BOW", 10: "EQ_MOON_CHARM"
}

var _path: String = Store.SAVE_PATH
var _characters: Array = []
var _stages: Array = []
var _skills: Array = []
var _enemy_catalog: Dictionary = {}
var _gear_catalog: Dictionary = {}
var _profile: Dictionary = {}
var _battle = Battle.new()
var _stage: int = 0
var _start_revision: int = -1
var _settled: bool = false

func initialize(profile_path: String = Store.SAVE_PATH) -> Dictionary:
	_path = profile_path
	_characters = Repo.load_array("res://data/characters.json")
	_stages = Repo.load_array("res://data/stages.json")
	_skills = Repo.load_array("res://data/skills.json")
	_gear_catalog = Gear.build_catalog(Repo.load_array("res://data/equipment.json"))
	_enemy_catalog.clear()
	for raw in Repo.load_array("res://data/enemies.json"):
		if typeof(raw) != TYPE_DICTIONARY or _enemy_catalog.has(str(raw.get("id", ""))):
			return _result(false, "invalid_enemy_catalog")
		_enemy_catalog[str(raw["id"])] = raw.duplicate(true)
	if _characters.size() != 8 or _stages.size() != STAGE_COUNT or _skills.size() != 16 or _gear_catalog.is_empty() or _enemy_catalog.is_empty():
		return _result(false, "missing_catalog")
	for index in range(STAGE_COUNT):
		var entry: Dictionary = _stages[index]
		if str(entry.get("id", "")) != "STG_%03d" % (index + 1) or int(entry.get("stage", -1)) != index + 1:
			return _result(false, "invalid_stage_order")
		var ids: Variant = entry.get("enemy_ids", null)
		if typeof(ids) != TYPE_ARRAY or ids.is_empty() or ids.size() > Battle.MAX_ENCOUNTER_SIZE:
			return _result(false, "invalid_stage_encounter")
		for id in ids:
			if not _enemy_catalog.has(str(id)):
				return _result(false, "unknown_stage_enemy")
	var progression = M3Model.new()
	var initialized: Dictionary = progression.initialize(_path)
	if not bool(initialized.get("ok", false)):
		return _result(false, str(initialized.get("reason", "invalid_profile")))
	_profile = progression.snapshot()
	_stage = 0
	_start_revision = -1
	_settled = false
	return _result(true, "ok")

func available_stages() -> Array:
	var result: Array = []
	if _profile.is_empty():
		return result
	for i in range(STAGE_COUNT):
		var stage: int = i + 1
		result.append({
			"stage": stage,
			"id": str(_stages[i].get("id", "")),
			"unlocked": _unlocked(stage, _profile),
			"cleared": _profile["economy_state"]["seen_events"].has(_clear_id(stage))
		})
	return result

func profile_snapshot() -> Dictionary:
	return _profile.duplicate(true)

func battle_snapshot() -> Dictionary:
	return _battle.snapshot()

func current_stage() -> int:
	return _stage

func start_stage(stage: int, party_ids: Array) -> Dictionary:
	if _profile.is_empty():
		return _result(false, "not_initialized")
	## Reload before authorizing each challenge: do not use a stale M4 cache
	## after M3 growth/equipment transactions or an external process save.
	var loaded: Dictionary = Store.load_profile(_path, _gear_catalog, _characters)
	if not bool(loaded.get("ok", false)):
		return _result(false, str(loaded.get("reason", "profile_error")))
	var source: Dictionary = loaded["profile"]
	if stage < 1 or stage > STAGE_COUNT or not _unlocked(stage, source):
		return _result(false, "stage_locked")
	if party_ids.size() < 3 or party_ids.size() > Battle.MAX_PARTY_SIZE:
		return _result(false, "invalid_party_size")
	var roster: Dictionary = {}
	for entry in _characters:
		roster[str(entry["id"])] = entry
	var members: Array = []
	var used: Dictionary = {}
	for raw_id in party_ids:
		if typeof(raw_id) != TYPE_STRING:
			return _result(false, "invalid_party")
		var hero_id: String = str(raw_id)
		if used.has(hero_id) or not roster.has(hero_id) or not source["heroes"].has(hero_id) or not source["loadouts"].has(hero_id):
			return _result(false, "invalid_party")
		used[hero_id] = true
		var stats: Dictionary = Gear.stats_for(source["heroes"][hero_id], roster[hero_id], source["loadouts"][hero_id], source["economy_state"]["inventory"], _gear_catalog)
		if stats.is_empty():
			return _result(false, "invalid_hero_stats")
		var unit: Dictionary = roster[hero_id].duplicate(true)
		unit["base_stats"] = stats
		members.append(unit)
	var encounter: Array = []
	var stage_def: Dictionary = _stages[stage - 1]
	for id in stage_def["enemy_ids"]:
		var foe: Dictionary = _enemy_catalog[str(id)].duplicate(true)
		foe["hp"] = maxi(1, ceili(float(foe["hp"]) * pow(1.07, float(stage - 1))))
		foe["atk"] = maxi(1, ceili(float(foe["atk"]) * pow(1.05, float(stage - 1))))
		foe["def"] = maxi(0, ceili(float(foe["def"]) + 2.2 * float(stage - 1)))
		encounter.append(foe)
	var next_battle = Battle.new()
	if not next_battle.configure_skills(_skills):
		return _result(false, "invalid_skill_catalog")
	next_battle.setup(members, encounter, 20261112 + stage * 1009, false)
	if str(next_battle.snapshot().get("state", "")) != "running":
		return _result(false, "battle_setup_failed")
	_profile = source
	_battle = next_battle
	_stage = stage
	_start_revision = int(source["revision"])
	_settled = false
	return _result(true, "ok")

func advance_ticks(count: int) -> Dictionary:
	if _stage == 0 or _settled:
		return _battle.snapshot()
	return _battle.step_ticks(clampi(count, 0, 200))

func settle_victory() -> Dictionary:
	if _stage == 0 or _settled:
		return _result(false, "not_settleable")
	if str(_battle.snapshot().get("state", "")) != "victory":
		return _result(false, "not_victory")
	var loaded: Dictionary = Store.load_profile(_path, _gear_catalog, _characters)
	if not bool(loaded.get("ok", false)):
		return _result(false, str(loaded.get("reason", "profile_error")))
	var current: Dictionary = loaded["profile"]
	if int(current["revision"]) != _start_revision:
		return _result(false, "stale_revision")
	if not _unlocked(_stage, current):
		return _result(false, "stage_locked")
	var first_clear: bool = not current["economy_state"]["seen_events"].has(_clear_id(_stage))
	var event_id: String = _clear_id(_stage) if first_clear else "stage:replay:%03d:r%d" % [_stage, _start_revision]
	var gold: int = 120 + 30 * _stage
	var xp: int = 160 + 35 * _stage
	var rewards: Dictionary = {"gold": gold, "xp_crystals": xp}
	if first_clear:
		rewards["enhancement_stones"] = 2 + int(_stage / 3)
		if _stage in [5, 10]:
			rewards["ascension_stones"] = 5
	var items: Array = []
	if first_clear and FIRST_CLEAR_ITEMS.has(_stage):
		items.append(FIRST_CLEAR_ITEMS[_stage])
	var paid: Dictionary = Economy.try_claim(current["economy_state"], _gear_catalog, event_id, rewards, items)
	if not bool(paid.get("ok", false)):
		return _result(false, str(paid.get("reason", "reward_rejected")))
	var next: Dictionary = current.duplicate(true)
	next["economy_state"] = paid["state"]
	next["highest_cleared_stage"] = maxi(int(next["highest_cleared_stage"]), _stage)
	var saved: Dictionary = Store.save_profile(next, _gear_catalog, _characters, _path)
	if not bool(saved.get("ok", false)):
		return _result(false, str(saved.get("reason", "save_failed")))
	_profile = saved["profile"]
	_settled = true
	return {
		"ok": true, "reason": "ok", "stage": _stage,
		"first_clear": first_clear, "event_id": event_id,
		"rewards": rewards.duplicate(true), "items": items.duplicate(true),
		"profile": _profile.duplicate(true)
	}

func _unlocked(stage: int, profile: Dictionary) -> bool:
	if stage < 1 or stage > STAGE_COUNT or profile.is_empty():
		return false
	return stage == 1 or profile["economy_state"]["seen_events"].has(_clear_id(stage - 1))

func _clear_id(stage: int) -> String:
	return "stage:clear:%03d" % stage

func _result(ok: bool, reason: String) -> Dictionary:
	return {"ok": ok, "reason": reason}
