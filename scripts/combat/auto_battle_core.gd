extends RefCounted
## M2-1 provisional combat core. Fixed-step data simulation, intentionally not wired
## into the M1 debug UI or game saves. Skill execution/status effects come later.
const Damage = preload("res://scripts/combat/damage_calculator.gd")
const TargetAI = preload("res://scripts/combat/target_selector.gd")
const SkillTargeting = preload("res://scripts/combat/skill_targeting.gd")
const Status = preload("res://scripts/combat/status_effects.gd")
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
var _skill_catalog: Dictionary = {}
var _auto_ultimates: bool = true

## Initial M2 slice accepts 3 heroes, but allows 1..5 to avoid hardcoding
## an obsolete formation. Boss fights may be represented by one enemy.
## Invalid catalogues are rejected as a unit: the previous valid catalogue stays.
## Call before or after setup; this method never changes the source JSON.
func configure_skills(skills: Array) -> bool:
	var built: Dictionary = {}
	var targets: Array = ["SINGLE_ENEMY", "ENEMY_BACK", "UP_TO_3_ENEMIES", "ALL_ENEMIES", "SELF", "ALLY_LOW_HP", "ALL_ALLIES"]
	for entry in skills:
		if typeof(entry) != TYPE_DICTIONARY:
			return false
		var id: String = str(entry.get("id", ""))
		var category: String = str(entry.get("category", ""))
		if id.is_empty() or built.has(id) or not category in ["ACTIVE", "ULTIMATE"] or not str(entry.get("target", "")) in targets:
			return false
		if float(entry.get("coefficient", -1.0)) < 0.0 or float(entry.get("cooldown_sec", -1.0)) < 0.0:
			return false
		built[id] = entry.duplicate(true)
	_skill_catalog = built
	return true

## When disabled, a manual ultimate must be queued for each actor.
func set_auto_ultimates(enabled: bool) -> void:
	_auto_ultimates = enabled

## A UI may queue before 100 energy; queued use waits for next ready action.
func request_ultimate(team: String, unit_id: String) -> bool:
	if _state != "running":
		return false
	var unit: Dictionary = _living_unit(team, unit_id)
	if unit.is_empty() or bool(unit.get("ultimate_requested", false)) or _find_skill(unit, "ULTIMATE").is_empty():
		return false
	unit["ultimate_requested"] = true
	return true

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
		_process_statuses()
		if _state != "running":
			break
		var ready: Array = []
		for unit in _allies + _enemies:
			if int(unit["hp"]) <= 0 or Status.frozen(unit):
				continue
			unit["action_gauge"] = int(unit["action_gauge"]) + Status.gauge_gain(unit)
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
				_perform_action(actor)
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

## M2-4 status policy hooks: seconds are never used inside the simulation.
## Returns false when there is no valid living target or immunity rejects it.
func add_status(team: String, unit_id: String, kind: String, duration_ticks: int, potency: float = 0.0) -> bool:
	if _state != "running":
		return false
	var unit: Dictionary = _living_unit(team, unit_id)
	if unit.is_empty():
		return false
	return _apply_status_to_unit(unit, unit, kind, duration_ticks, potency)

func remove_status(team: String, unit_id: String, selector: String = "ALL") -> int:
	var unit: Dictionary = _living_unit(team, unit_id)
	if unit.is_empty():
		return 0
	var deleted: Array = Status.remove(unit, selector)
	for kind in deleted:
		if str(kind) == "TAUNT":
			unit["taunt_until_tick"] = 0
		_record_event({"tick": _ticks, "type": "status_removed", "actor_id": unit_id, "target_id": unit_id, "status_id": str(kind)})
	return deleted.size()

func set_status_immunity(team: String, unit_id: String, kind: String, enabled: bool) -> bool:
	if not Status.valid(kind):
		return false
	var unit: Dictionary = _living_unit(team, unit_id)
	if unit.is_empty():
		return false
	var kinds: Array = unit.get("immunities", [])
	if enabled and not kind in kinds:
		kinds.append(kind)
	elif not enabled:
		kinds.erase(kind)
	unit["immunities"] = kinds
	return true

func _apply_status_to_unit(actor: Dictionary, target: Dictionary, kind: String, duration_ticks: int, potency: float = 0.0) -> bool:
	if not Status.apply(target, kind, _ticks, duration_ticks, potency):
		if Status.valid(kind) and Status.is_immune(target, kind):
			_record_event({"tick": _ticks, "type": "status_immune", "actor_id": str(actor["id"]), "target_id": str(target["id"]), "status_id": kind})
		return false
	if kind == "TAUNT":
		apply_taunt(str(target["team"]), str(target["id"]), duration_ticks)
	_record_event({"tick": _ticks, "type": "status_applied", "actor_id": str(actor["id"]), "target_id": str(target["id"]), "status_id": kind, "stacks": int(target["statuses"][kind]["stacks"])})
	return true

## Periodic DOT precedes HOT regardless of insertion order. A finishing DOT
## can end a battle before any unit gains action gauge for that tick.
func _process_statuses() -> void:
	for unit in _allies + _enemies:
		if _state != "running":
			return
		if int(unit["hp"]) <= 0:
			continue
		var operations: Array = Status.advance(unit, _ticks)
		for operation in operations:
			var kind: String = str(operation.get("status_id", ""))
			if str(operation.get("kind", "")) == "expired":
				if kind == "TAUNT":
					unit["taunt_until_tick"] = 0
				_record_event({"tick": _ticks, "type": "status_expired", "target_id": str(unit["id"]), "status_id": kind})
				continue
			if int(unit["hp"]) <= 0:
				continue
			var raw: int = int(operation.get("amount", 0))
			var applied: int = 0
			if bool(operation.get("heal", false)):
				applied = mini(raw, int(unit["max_hp"]) - int(unit["hp"]))
				unit["hp"] = int(unit["hp"]) + applied
			else:
				var absorbed: int = mini(int(unit["shield"]), raw)
				unit["shield"] = int(unit["shield"]) - absorbed
				applied = mini(int(unit["hp"]), raw - absorbed)
				unit["hp"] = int(unit["hp"]) - applied
			_record_event({"tick": _ticks, "type": "status_tick", "target_id": str(unit["id"]), "status_id": kind, "amount": applied, "raw": raw, "heal": bool(operation.get("heal", false))})
			_check_result()
			if _state != "running":
				return

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
		"shield": 0,
		"next_active_tick": 0,
		"ultimate_requested": false,
		"statuses": {},
		"immunities": source.get("immunities", []).duplicate(true),
		"action_gauge": 0,
		"skill_ids": source.get("skill_ids", []).duplicate(true)
	}

## Deterministic skill-first priority: ultimate > active > basic.
func _perform_action(actor: Dictionary) -> void:
	var ultimate: Dictionary = _find_skill(actor, "ULTIMATE")
	if not ultimate.is_empty() and int(actor["energy"]) >= 100 and (_auto_ultimates or bool(actor["ultimate_requested"])):
		if _perform_skill(actor, ultimate):
			actor["energy"] = 0
			actor["ultimate_requested"] = false
			return
	var active: Dictionary = _find_skill(actor, "ACTIVE")
	if not active.is_empty() and _ticks >= int(actor["next_active_tick"]):
		if _perform_skill(actor, active):
			actor["next_active_tick"] = _ticks + maxi(1, ceili(float(active.get("cooldown_sec", 0.0)) * float(TICKS_PER_SECOND)))
			actor["energy"] = mini(100, int(actor["energy"]) + 10)
			return
	_perform_basic_attack(actor)

func _find_skill(actor: Dictionary, category: String) -> Dictionary:
	for id in actor.get("skill_ids", []):
		var skill: Dictionary = _skill_catalog.get(str(id), {})
		if str(skill.get("category", "")) == category:
			return skill
	return {}

func _perform_skill(actor: Dictionary, skill: Dictionary) -> bool:
	var chosen: Array = SkillTargeting.select(actor, skill, _allies, _enemies, _ticks)
	if chosen.is_empty():
		return false
	var effect: String = str(skill.get("effect_type", "DAMAGE"))
	var coefficient: float = float(skill.get("coefficient", 1.0))
	var id: String = str(skill.get("id", ""))
	_record_event({"tick": _ticks, "type": "skill_cast", "actor_id": str(actor["id"]), "skill_id": id, "category": str(skill["category"]), "effect_type": effect, "deferred_effect": ""})
	if effect in ["SHIELD", "TAUNT_SHIELD"]:
		for unit in chosen:
			var amount: int = maxi(1, int(floor(float(actor["max_hp"]) * coefficient)))
			unit["shield"] = int(unit["shield"]) + amount
			_record_event({"tick": _ticks, "type": "shield", "actor_id": str(actor["id"]), "target_id": str(unit["id"]), "amount": amount, "skill_id": id})
	if effect in ["HEAL", "HEAL_REGEN"]:
		for unit in chosen:
			var amount: int = maxi(0, int(floor(float(actor["atk"]) * coefficient)))
			var restored: int = mini(amount, int(unit["max_hp"]) - int(unit["hp"]))
			unit["hp"] = int(unit["hp"]) + restored
			_record_event({"tick": _ticks, "type": "heal", "actor_id": str(actor["id"]), "target_id": str(unit["id"]), "amount": restored, "skill_id": id})
	if effect in ["TAUNT", "TAUNT_SHIELD"]:
		if _apply_status_to_unit(actor, actor, "TAUNT", 3 * TICKS_PER_SECOND):
			_record_event({"tick": _ticks, "type": "taunt", "actor_id": str(actor["id"]), "target_id": str(actor["id"]), "duration_ticks": 3 * TICKS_PER_SECOND, "skill_id": id})
	if effect == "TAUNT":
		_apply_status_to_unit(actor, actor, "DEF_UP", 4 * TICKS_PER_SECOND, coefficient)
	if effect == "HEAL_REGEN":
		for unit in chosen:
			_apply_status_to_unit(actor, unit, "REGEN", 5 * TICKS_PER_SECOND)
	if effect in ["SHIELD", "HEAL", "HEAL_REGEN", "TAUNT", "TAUNT_SHIELD"]:
		return true
	if effect == "MULTIHIT_3":
		for _i in range(3):
			if int(chosen[0]["hp"]) > 0 and _state == "running":
				_deal_skill_damage(actor, chosen[0], coefficient, id)
		return true
	for i in range(chosen.size()):
		if _state != "running":
			break
		var scale: float = coefficient
		if effect == "CHAIN":
			scale = [1.5, 1.1, 0.75][mini(i, 2)]
		if int(chosen[i]["hp"]) > 0:
			_deal_skill_damage(actor, chosen[i], scale, id)
			if int(chosen[i]["hp"]) > 0 and _state == "running":
				match effect:
					"BURN":
						_apply_status_to_unit(actor, chosen[i], "BURN", 4 * TICKS_PER_SECOND)
					"POISON":
						_apply_status_to_unit(actor, chosen[i], "POISON", 6 * TICKS_PER_SECOND)
					"SLOW":
						_apply_status_to_unit(actor, chosen[i], "SLOW", 4 * TICKS_PER_SECOND)
					"DEF_DOWN":
						_apply_status_to_unit(actor, chosen[i], "DEF_DOWN", 6 * TICKS_PER_SECOND)
					"FREEZE_30":
						if not Status.is_immune(chosen[i], "FREEZE") and _rng.randf() < 0.30:
							_apply_status_to_unit(actor, chosen[i], "FREEZE", 2 * TICKS_PER_SECOND)
	return true

func _deal_skill_damage(actor: Dictionary, target: Dictionary, coefficient: float, skill_id: String) -> void:
	var crit: bool = _rng.randf() < float(actor["crit"])
	var crit_mult: float = float(actor["crit_damage"]) if crit else 1.0
	var variance: float = _rng.randf_range(0.95, 1.05)
	var element: float = _element_multiplier(str(actor["element"]), str(target["element"]))
	var raw: int = Damage.calculate(float(actor["atk"]), coefficient, Status.effective_defense(target), element, crit_mult, variance)
	var absorbed: int = mini(int(target["shield"]), raw)
	target["shield"] = int(target["shield"]) - absorbed
	var lost: int = mini(int(target["hp"]), raw - absorbed)
	target["hp"] = int(target["hp"]) - lost
	actor["threat"] = mini(TargetAI.MAX_THREAT, int(actor["threat"]) + lost)
	_record_event({"tick": _ticks, "type": "skill_hit", "actor_id": str(actor["id"]), "target_id": str(target["id"]), "skill_id": skill_id, "damage": raw, "hp_loss": lost, "absorbed": absorbed, "critical": crit})
	_check_result()

func _record_event(event: Dictionary) -> void:
	_events.append(event)
	if _events.size() > MAX_EVENT_HISTORY:
		_events.pop_front()

func _perform_basic_attack(actor: Dictionary) -> void:
	var targets: Array = _enemies if str(actor["team"]) == "ally" else _allies
	var target: Dictionary = TargetAI.choose(actor, targets, _ticks)
	if target.is_empty():
		return
	var is_critical: bool = _rng.randf() < float(actor["crit"])
	var multiplier: float = float(actor["crit_damage"]) if is_critical else 1.0
	var variance: float = _rng.randf_range(0.95, 1.05)
	var element: float = _element_multiplier(str(actor["element"]), str(target["element"]))
	var damage: int = Damage.calculate(float(actor["atk"]), 1.0, Status.effective_defense(target), element, multiplier, variance)
	var hp_before: int = int(target["hp"])
	var absorbed: int = mini(int(target["shield"]), damage)
	target["shield"] = int(target["shield"]) - absorbed
	var effective_damage: int = mini(hp_before, damage - absorbed)
	target["hp"] = hp_before - effective_damage
	actor["energy"] = mini(100, int(actor["energy"]) + 10)
	actor["threat"] = mini(TargetAI.MAX_THREAT, int(actor["threat"]) + effective_damage)
	_record_event({
		"tick": _ticks,
		"type": "basic_attack",
		"actor_id": str(actor["id"]),
		"target_id": str(target["id"]),
		"damage": damage,
		"critical": is_critical
	})
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
