extends RefCounted
## M2-1 provisional combat core. Fixed-step data simulation, intentionally not wired
## into the M1 debug UI or game saves. Skill execution/status effects come later.
const Damage = preload("res://scripts/combat/damage_calculator.gd")
const TargetAI = preload("res://scripts/combat/target_selector.gd")
const TICKS_PER_SECOND: int = 20
const ACTION_GAUGE_REQUIRED: int = 2000
const MAX_PARTY_SIZE: int = 5
const MAX_ENCOUNTER_SIZE: int = 5
const MAX_EVENT_HISTORY: int = 64

var _rng := RandomNumberGenerator.new()
var _allies: Array = []
var _enemies: Array = []
var _events: Array = []
var _ticks: int = 0
var _time_limit_ticks: int = 0
var _state: String = "idle"

## Initial M2 slice accepts 3 heroes, but allows 1..5 to avoid hardcoding
## an obsolete formation. Boss fights may be represented by one enemy.
func setup(party: Array, encounter: Array, seed: int = 42, is_boss: bool = false) -> void:
	_allies.clear()
	_enemies.clear()
	_events.clear()
	_ticks = 0
	_rng.seed = seed
	_time_limit_ticks = (120 if is_boss else 90) * TICKS_PER_SECOND
	for i in range(mini(party.size(), MAX_PARTY_SIZE)):
		if typeof(party[i]) == TYPE_DICTIONARY:
			_allies.append(_make_unit(party[i], "ally", i))
	for i in range(mini(encounter.size(), MAX_ENCOUNTER_SIZE)):
		if typeof(encounter[i]) == TYPE_DICTIONARY:
			_enemies.append(_make_unit(encounter[i], "enemy", i))
	_state = "running" if not _allies.is_empty() and not _enemies.is_empty() else "invalid"

func step_ticks(count: int = 1) -> Dictionary:
	for _i in range(maxi(0, count)):
		if _state != "running":
			break
		_ticks += 1
		var ready: Array = []
		for unit in _allies + _enemies:
			if int(unit["hp"]) <= 0:
				continue
			unit["action_gauge"] = int(unit["action_gauge"]) + int(unit["spd"])
			if int(unit["action_gauge"]) >= ACTION_GAUGE_REQUIRED:
				unit["action_gauge"] = int(unit["action_gauge"]) - ACTION_GAUGE_REQUIRED
				ready.append(unit)
		## Speed breaks ties deterministically; equal speeds retain formation
		## order (allies before enemies) from the collected array.
		while not ready.is_empty() and _state == "running":
			var fastest: int = 0
			for j in range(1, ready.size()):
				if int(ready[j]["spd"]) > int(ready[fastest]["spd"]):
					fastest = j
			var actor: Dictionary = ready.pop_at(fastest)
			if int(actor["hp"]) > 0:
				_perform_basic_attack(actor)
		if _ticks >= _time_limit_ticks and _state == "running":
			_state = "defeat"
	return snapshot()

## Used by a future 20Hz presenter. 2x/3x changes how many logical
## ticks are advanced; it never modifies RNG, cooldowns or combat formulas.
func advance_frame(speed_multiplier: int = 1) -> Dictionary:
	return step_ticks(clampi(speed_multiplier, 1, 3))

## A skill may add threat later; current basic attacks accrue threat automatically.
## False means invalid team/id, a dead unit, nonpositive amount or stopped fight.
func add_threat(team: String, unit_id: String, amount: int) -> bool:
	if _state != "running" or amount <= 0:
		return false
	var unit: Dictionary = _living_unit(team, unit_id)
	if unit.is_empty():
		return false
	unit["threat"] = mini(TargetAI.MAX_THREAT, int(unit["threat"]) + mini(TargetAI.MAX_THREAT, amount))
	return true

## Timed targeting override; not an implemented status effect or taunt skill.
## Expiry is exclusive: cast at tick 0 for 3 ticks targets at ticks 1 and 2,
## then defaults to normal AI targeting on tick 3.
func apply_taunt(team: String, unit_id: String, duration_ticks: int) -> bool:
	if _state != "running" or duration_ticks <= 0:
		return false
	var source: Dictionary = _living_unit(team, unit_id)
	if source.is_empty():
		return false
	var members: Array = _allies if team == "ally" else _enemies
	for unit in members:
		unit["taunt_until_tick"] = 0
	var remaining: int = maxi(0, _time_limit_ticks - _ticks + 1)
	source["taunt_until_tick"] = _ticks + mini(duration_ticks, remaining)
	return true

func _living_unit(team: String, unit_id: String) -> Dictionary:
	var members: Array = []
	if team == "ally":
		members = _allies
	elif team == "enemy":
		members = _enemies
	else:
		return {}
	for unit in members:
		if str(unit.get("id", "")) == unit_id and int(unit.get("hp", 0)) > 0:
			return unit
	return {}

func snapshot() -> Dictionary:
	return {
		"state": _state,
		"ticks": _ticks,
		"elapsed_seconds": float(_ticks) / float(TICKS_PER_SECOND),
		"time_limit_seconds": _time_limit_ticks / TICKS_PER_SECOND,
		"allies": _allies.duplicate(true),
		"enemies": _enemies.duplicate(true),
		"recent_events": _events.duplicate(true)
	}

func _make_unit(source: Dictionary, team: String, slot: int) -> Dictionary:
	var stats: Dictionary = source.get("base_stats", source)
	var hp: int = maxi(1, int(stats.get("hp", 1)))
	var role: String = str(source.get("role", "MELEE"))
	return {
		"id": str(source.get("id", "%s_%d" % [team, slot])),
		"name": str(source.get("name", "?")),
		"team": team,
		"slot": slot,
		"role": role,
		"row": TargetAI.initial_row(source, slot),
		"threat": TargetAI.initial_threat(role),
		"taunt_until_tick": 0,
		"element": str(source.get("element", "NEUTRAL")),
		"hp": hp,
		"max_hp": hp,
		"atk": maxi(1, int(stats.get("atk", 1))),
		"def": maxi(0, int(stats.get("def", 0))),
		"spd": maxi(1, int(stats.get("spd", 90))),
		"crit": clampf(float(stats.get("crit", 0.0)), 0.0, 1.0),
		"crit_damage": maxf(1.0, float(stats.get("crit_damage", 1.5))),
		"energy": 0,
		"action_gauge": 0,
		"skill_ids": source.get("skill_ids", []).duplicate(true)
	}

func _perform_basic_attack(actor: Dictionary) -> void:
	var targets: Array = _enemies if str(actor["team"]) == "ally" else _allies
	var target: Dictionary = TargetAI.choose(actor, targets, _ticks)
	if target.is_empty():
		return
	var is_critical: bool = _rng.randf() < float(actor["crit"])
	var multiplier: float = float(actor["crit_damage"]) if is_critical else 1.0
	var variance: float = _rng.randf_range(0.95, 1.05)
	var element: float = _element_multiplier(str(actor["element"]), str(target["element"]))
	var damage: int = Damage.calculate(float(actor["atk"]), 1.0, float(target["def"]), element, multiplier, variance)
	target["hp"] = maxi(0, int(target["hp"]) - damage)
	actor["energy"] = mini(100, int(actor["energy"]) + 10)
	actor["threat"] = mini(TargetAI.MAX_THREAT, int(actor["threat"]) + damage)
	_events.append({
		"tick": _ticks,
		"type": "basic_attack",
		"actor_id": str(actor["id"]),
		"target_id": str(target["id"]),
		"damage": damage,
		"critical": is_critical
	})
	if _events.size() > MAX_EVENT_HISTORY:
		_events.pop_front()
	_check_result()

func _element_multiplier(attacker: String, defender: String) -> float:
	var favored := {
		"FIRE": "NATURE",
		"NATURE": "LIGHTNING",
		"LIGHTNING": "ICE",
		"ICE": "FIRE",
		"LIGHT": "DARK",
		"DARK": "LIGHT"
	}
	if str(favored.get(attacker, "")) == defender:
		return 1.15
	if str(favored.get(defender, "")) == attacker:
		return 0.90
	return 1.0

func _check_result() -> void:
	var ally_living: int = 0
	var enemy_living: int = 0
	for unit in _allies:
		if int(unit["hp"]) > 0:
			ally_living += 1
	for unit in _enemies:
		if int(unit["hp"]) > 0:
			enemy_living += 1
	if enemy_living == 0:
		_state = "victory"
	elif ally_living == 0:
		_state = "defeat"
