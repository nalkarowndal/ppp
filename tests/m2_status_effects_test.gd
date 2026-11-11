extends SceneTree
## M2-4 fixed-step status lifecycle and M2-3 skill regression.
const Battle = preload("res://scripts/combat/auto_battle_core.gd")
const Repo = preload("res://scripts/core/data_repository.gd")
var failures: Array[String] = []

func _initialize() -> void:
	var probe = Battle.new()
	if not probe.has_method("add_status") or not probe.has_method("remove_status") or not probe.has_method("set_status_immunity"):
		_expect(false, "M2-4 status apply / cleanse / immunity public APIs exist")
		_finish()
		return
	_test_dot_ticks()
	_test_stacks_refresh()
	_test_freeze_and_slow()
	_test_defense()
	_test_immunity_cleanse()
	_test_regen_order()
	_test_skill_wiring()
	_test_replay()
	_test_dot_shield_and_victory()
	_test_immune_skill_and_taunt_expiry()
	_finish()

func _unit(id: String, hp: int = 1000, spd: int = 1, atk: int = 1, defense: int = 0) -> Dictionary:
	return {"id": id, "name": id, "role": "MELEE", "element": "NEUTRAL", "hp": hp, "atk": atk, "def": defense, "spd": spd, "crit": 0.0}

func _battle(ally: Dictionary, enemy: Dictionary, seed: int = 9) -> Variant:
	var b = Battle.new()
	b.setup([ally], [enemy], seed)
	return b

func _status(state: Dictionary, team: String, effect: String) -> Dictionary:
	var group: String = "allies" if team == "ally" else "enemies"
	return state[group][0].get("statuses", {}).get(effect, {})

func _events(state: Dictionary, kind: String, status_id: String = "") -> Array:
	var events: Array = []
	for e in state["recent_events"]:
		if str(e.get("type", "")) == kind and (status_id == "" or str(e.get("status_id", "")) == status_id):
			events.append(e)
	return events

func _test_dot_ticks() -> void:
	var b = _battle(_unit("H"), _unit("E"))
	_expect(b.add_status("enemy", "E", "BURN", 40), "BURN accepted")
	_expect(int(_status(b.snapshot(), "enemy", "BURN").get("stacks", -1)) == 1, "burn tracked as runtime status")
	_expect(int(b.step_ticks(19)["enemies"][0]["hp"]) == 1000, "no damage before 1s pulse")
	var first: Dictionary = b.step_ticks(1)
	_expect(int(first["enemies"][0]["hp"]) == 980, "2% max HP BURN at tick 20")
	_expect(_events(first, "status_tick", "BURN").size() == 1, "BURN pulse event")
	var end: Dictionary = b.step_ticks(20)
	_expect(int(end["enemies"][0]["hp"]) == 960 and _status(end, "enemy", "BURN").is_empty(), "BURN pulses on expiry tick then is removed")
	_expect(int(b.step_ticks(20)["enemies"][0]["hp"]) == 960, "expired DOT no phantom tick")

func _test_stacks_refresh() -> void:
	var b = _battle(_unit("H"), _unit("E"))
	for i in range(4):
		_expect(b.add_status("enemy", "E", "POISON", 40), "POISON stacking accepted")
	_expect(int(_status(b.snapshot(), "enemy", "POISON").get("stacks", -1)) == 3, "poison stack cap 3")
	b.step_ticks(10)
	_expect(b.add_status("enemy", "E", "POISON", 40), "poison refresh accepts reapply")
	var snap: Dictionary = b.snapshot()
	_expect(int(_status(snap, "enemy", "POISON").get("expires_tick", -1)) == 50, "reapply refreshes expiration")
	var first: Dictionary = b.step_ticks(10)
	_expect(int(first["enemies"][0]["hp"]) == 970, "reapply must not postpone scheduled pulse at tick 20")
	var second: Dictionary = b.step_ticks(20)
	_expect(int(second["enemies"][0]["hp"]) == 940, "3-stack poison deals 30 per second")
	b.step_ticks(10)
	_expect(_status(b.snapshot(), "enemy", "POISON").is_empty(), "refreshed poison expires at tick50")

func _test_freeze_and_slow() -> void:
	var enemy: Dictionary = _unit("DUMMY", 100000)
	var attacker: Dictionary = _unit("HERO", 1000, 2000, 10)
	var b = _battle(attacker, enemy)
	_expect(b.add_status("ally", "HERO", "FREEZE", 3), "freeze status applied")
	_expect(_events(b.step_ticks(2), "basic_attack").is_empty(), "freeze blocks action and gauge in first two ticks")
	var third: Dictionary = b.step_ticks(1)
	_expect(_events(third, "basic_attack").size() == 1, "freeze expires before tick3 action")
	_expect(_status(third, "ally", "FREEZE").is_empty(), "freeze removed at expiry")

	var slowed: Dictionary = _unit("SLOW_HERO", 1000, 1000, 10)
	var sb = _battle(slowed, enemy)
	_expect(sb.add_status("ally", "SLOW_HERO", "SLOW", 8, 0.5), "custom slow potency applied")
	_expect(_events(sb.step_ticks(3), "basic_attack").is_empty(), "slow halves gauge gain: no action until tick4")
	_expect(_events(sb.step_ticks(1), "basic_attack").size() == 1, "slowed hero ready on tick4")
	_expect(int(sb.snapshot()["allies"][0]["spd"]) == 1000, "slow does not mutate base SPD")

func _test_defense() -> void:
	var attacker: Dictionary = _unit("STRIKER", 1000, 2000, 200)
	var armored: Dictionary = _unit("ARMORED", 100000, 1, 1, 100)
	var base = _battle(attacker, armored, 91)
	var weaken = _battle(attacker, armored, 91)
	var strengthen = _battle(attacker, armored, 91)
	_expect(weaken.add_status("enemy", "ARMORED", "DEF_DOWN", 100, 0.5), "def-down applies")
	_expect(strengthen.add_status("enemy", "ARMORED", "DEF_UP", 100, 0.5), "def-up applies")
	var base_hp: int = int(base.step_ticks(1)["enemies"][0]["hp"])
	var weak_hp: int = int(weaken.step_ticks(1)["enemies"][0]["hp"])
	var strong_hp: int = int(strengthen.step_ticks(1)["enemies"][0]["hp"])
	_expect(weak_hp < base_hp and base_hp < strong_hp, "DEF_DOWN increases damage and DEF_UP decreases damage")
	_expect(int(weaken.snapshot()["enemies"][0]["def"]) == 100, "defense modifiers never overwrite JSON base stat")

func _test_immunity_cleanse() -> void:
	var immune: Dictionary = _unit("IMMUNE")
	immune["immunities"] = ["BURN", "FREEZE"]
	var original: Dictionary = immune.duplicate(true)
	var b = _battle(immune, _unit("E"))
	_expect(not b.add_status("ally", "IMMUNE", "BURN", 40), "explicit BURN immunity rejects application")
	_expect(not b.add_status("ally", "IMMUNE", "FREEZE", 40), "explicit FREEZE immunity rejects control")
	_expect(b.add_status("ally", "IMMUNE", "POISON", 40), "nonimmune poison works")
	_expect(b.add_status("ally", "IMMUNE", "REGEN", 100), "positive regen works")
	_expect(b.remove_status("ally", "IMMUNE", "DEBUFF") == 1, "cleanse removes debuff only")
	_expect(_status(b.snapshot(), "ally", "POISON").is_empty(), "poison removed")
	_expect(not _status(b.snapshot(), "ally", "REGEN").is_empty(), "cleanse leaves buff")
	_expect(b.set_status_immunity("ally", "IMMUNE", "POISON", true), "runtime immunity can be enabled")
	_expect(not b.add_status("ally", "IMMUNE", "POISON", 40), "enabled immunity enforced")
	_expect(b.set_status_immunity("ally", "IMMUNE", "POISON", false), "runtime immunity can be disabled")
	_expect(b.add_status("ally", "IMMUNE", "POISON", 40), "removed immunity permits status")
	_expect(b.remove_status("ally", "IMMUNE", "ALL") == 2, "ALL purge removes buffs and debuffs")
	_expect(immune == original, "source immunity and status data never mutated")
	_expect(not b.add_status("enemy", "MISSING", "BURN", 40), "missing target rejected")
	_expect(not b.add_status("ally", "IMMUNE", "BURN", 0), "zero duration rejected")
	_expect(not b.add_status("ally", "IMMUNE", "UNKNOWN", 40), "unsupported status rejected")

func _test_regen_order() -> void:
	var b = _battle(_unit("H"), _unit("E"))
	_expect(b.add_status("ally", "H", "REGEN", 20, 0.03), "regen added first")
	_expect(b.add_status("ally", "H", "BURN", 20, 0.02), "burn added second")
	var state: Dictionary = b.step_ticks(20)
	_expect(int(state["allies"][0]["hp"]) == 1000, "DOT resolves before HOT regardless of insertion order")
	_expect(_events(state, "status_tick", "REGEN").size() == 1, "regen tick emitted")
	_expect(_events(state, "status_tick", "BURN").size() == 1, "burn tick emitted")

func _fast_hero(id: String, hp: int = 10000, atk: int = 25) -> Dictionary:
	var h: Dictionary = _unit(id, hp, 2000, atk)
	var map: Dictionary = {
		"ARIA": ["SKL_ARIA_ACTIVE", "SKL_ARIA_ULTIMATE"],
		"SERENA": ["SKL_SERENA_ACTIVE", "SKL_SERENA_ULTIMATE"],
		"ELIN": ["SKL_ELIN_ACTIVE", "SKL_ELIN_ULTIMATE"],
		"LUNA": ["SKL_LUNA_ACTIVE", "SKL_LUNA_ULTIMATE"],
		"BELL": ["SKL_BELL_ACTIVE", "SKL_BELL_ULTIMATE"]
	}
	h["skill_ids"] = map.get(id, []).duplicate(true)
	return h

func _test_skill_wiring() -> void:
	var skills: Array = Repo.load_array("res://data/skills.json")
	var checks: Array = [
		["ARIA", "BURN", "enemy", 1],
		["SERENA", "SLOW", "enemy", 1],
		["ELIN", "POISON", "enemy", 1],
		["BELL", "DEF_UP", "ally", 1],
		["LUNA", "REGEN", "ally", 11],
		["ELIN", "DEF_DOWN", "enemy", 11]
	]
	for fixture in checks:
		var hero: String = str(fixture[0])
		var effect: String = str(fixture[1])
		var group: String = str(fixture[2])
		var ticks: int = int(fixture[3])
		var b = Battle.new()
		_expect(b.configure_skills(skills), "M2-4 skill catalogue valid")
		b.setup([_fast_hero(hero)], [_unit("E", 1000000)], 60)
		var state: Dictionary = b.step_ticks(ticks)
		_expect(not _status(state, group, effect).is_empty(), "%s skill applies actual %s status" % [hero, effect])
		_expect(_events(state, "status_applied", effect).size() >= 1, "%s application logged" % effect)
		if hero == "BELL":
			_expect(int(state["allies"][0]["taunt_until_tick"]) > ticks, "Bell taunt still controls targeting")
			_expect(b.remove_status("ally", "BELL", "TAUNT") == 1, "taunt can be dispelled")
			_expect(int(b.snapshot()["allies"][0]["taunt_until_tick"]) == 0, "dispelling taunt clears targeting override")

	var frozen_count: int = 0
	for seed in range(20):
		var ser = Battle.new()
		ser.configure_skills(skills)
		ser.setup([_fast_hero("SERENA")], [_unit("E", 1000000)], seed)
		var r: Dictionary = ser.step_ticks(11)
		if not _status(r, "enemy", "FREEZE").is_empty():
			frozen_count += 1
	_expect(frozen_count > 0 and frozen_count < 20, "Serena ultimate freeze uses chance rather than always/never")

func _test_replay() -> void:
	var skills: Array = Repo.load_array("res://data/skills.json")
	var a = Battle.new()
	var b = Battle.new()
	a.configure_skills(skills)
	b.configure_skills(skills)
	a.setup([_fast_hero("ARIA")], [_unit("E", 1000000)], 777)
	b.setup([_fast_hero("ARIA")], [_unit("E", 1000000)], 777)
	var first: Dictionary = a.step_ticks(90)
	for i in range(30):
		b.advance_frame(3)
	_expect(first == b.snapshot(), "status ticks and skill RNG remain identical at 1x/3x")

func _test_dot_shield_and_victory() -> void:
	var skills: Array = Repo.load_array("res://data/skills.json")
	var leon: Dictionary = _unit("LEON", 1000, 2000, 50)
	leon["skill_ids"] = ["SKL_LEON_ACTIVE", "SKL_LEON_ULTIMATE"]
	var b = Battle.new()
	b.configure_skills(skills)
	b.setup([leon], [_unit("E", 1000000)], 90)
	var first: Dictionary = b.step_ticks(1)
	var shield_before: int = int(first["allies"][0]["shield"])
	_expect(shield_before == 150, "Leon creates expected 15%-HP shield")
	_expect(b.add_status("ally", "LEON", "BURN", 20), "burn can hit shielded unit")
	var after: Dictionary = b.step_ticks(20)
	_expect(int(after["allies"][0]["hp"]) == 1000, "periodic burn is shielded before HP")
	_expect(int(after["allies"][0]["shield"]) == shield_before - 20, "DOT consumes exactly effective shield amount")

	var fatal = _battle(_unit("SURVIVOR", 10), _unit("VICTIM", 10))
	_expect(fatal.add_status("enemy", "VICTIM", "BURN", 20, 1.0), "lethal burn applies")
	var ended: Dictionary = fatal.step_ticks(100)
	_expect(str(ended["state"]) == "victory" and int(ended["ticks"]) == 20, "lethal DOT ends battle immediately before actions")
	_expect(_events(ended, "status_tick", "BURN").size() == 1, "lethal DOT logged exactly once")

func _test_immune_skill_and_taunt_expiry() -> void:
	var skills: Array = Repo.load_array("res://data/skills.json")
	var enemy: Dictionary = _unit("IMMUNE_TARGET", 1000000)
	enemy["immunities"] = ["BURN"]
	var before: Dictionary = enemy.duplicate(true)
	var fire = Battle.new()
	fire.configure_skills(skills)
	fire.setup([_fast_hero("ARIA")], [enemy], 91)
	var result: Dictionary = fire.step_ticks(1)
	_expect(int(result["enemies"][0]["hp"]) < 1000000, "status immunity does not cancel immediate attack damage")
	_expect(_status(result, "enemy", "BURN").is_empty(), "BURN-immune enemy never receives status")
	_expect(_events(result, "status_immune", "BURN").size() == 1, "skill immunity emits audit event")
	_expect(enemy == before, "skill immunity does not mutate source data")

	var bell = Battle.new()
	bell.configure_skills(skills)
	bell.setup([_fast_hero("BELL")], [_unit("E", 1000000)], 92)
	var cast: Dictionary = bell.step_ticks(1)
	_expect(not _status(cast, "ally", "TAUNT").is_empty(), "Bell creates status-linked taunt")
	var expired: Dictionary = bell.step_ticks(60)
	_expect(_status(expired, "ally", "TAUNT").is_empty(), "Bell taunt expires on tick61")
	_expect(int(expired["allies"][0]["taunt_until_tick"]) == 0, "expired TAUNT clears M2-2 targeting override")

func _expect(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)

func _finish() -> void:
	if failures.is_empty():
		print("M2-4 STATUS PASS: DOT, stacks, expiry, control, buffs, cleanse, immunity, skills, replay")
		quit(0)
		return
	for f in failures:
		push_error("M2-4 FAIL: " + f)
	quit(1)
