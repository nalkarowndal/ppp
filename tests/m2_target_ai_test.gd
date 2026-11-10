extends SceneTree
## Godot M2-2 behavioral regression. Run with --headless --path . --script.
const Battle = preload("res://scripts/combat/auto_battle_core.gd")
var failures: Array[String] = []

func _initialize() -> void:
	_test_role_policy()
	_test_frontline_depletion()
	_test_threat_and_taunt()
	_test_replay()
	if failures.is_empty():
		print("M2-2 TARGET AI PASS: roles, rows, threat, taunt, expiration, death, replay")
		quit(0)
		return
	for failure in failures:
		push_error("M2-2 FAIL: " + failure)
	quit(1)

func _unit(id: String, role: String, hp: int, spd: int = 1, row: String = "") -> Dictionary:
	var unit: Dictionary = {
		"id": id, "name": id, "role": role,
		"hp": hp, "atk": 1, "def": 0, "spd": spd, "crit": 0.0
	}
	if row != "":
		unit["row"] = row
	return unit

func _enemy_team() -> Array:
	return [
		_unit("FRONT_MELEE", "MELEE", 120, 1, "FRONT"),
		_unit("FRONT_DEF", "DEFENDER", 240, 1, "FRONT"),
		_unit("BACK_RANGE", "RANGED", 200, 1, "BACK"),
		_unit("BACK_WEAK", "MAGE", 50, 1, "BACK"),
		_unit("BACK_SUPPORT", "SUPPORT", 300, 1, "BACK")
	]

func _first_target(role: String, enemies: Array) -> String:
	var battle = Battle.new()
	battle.setup([_unit("ACTOR", role, 100000, 2000)], enemies, 11)
	var state: Dictionary = battle.step_ticks(1)
	var events: Array = state["recent_events"]
	return "" if events.is_empty() else str(events[0].get("target_id", ""))

func _last_target(battle: Variant) -> String:
	var events: Array = battle.snapshot()["recent_events"]
	return "" if events.is_empty() else str(events[-1].get("target_id", ""))

func _test_role_policy() -> void:
	var opponents: Array = _enemy_team()
	var cases: Array = [
		["WARRIOR", "FRONT_DEF"],
		["TANK", "FRONT_DEF"],
		["MELEE", "FRONT_DEF"],
		["DEFENDER", "FRONT_DEF"],
		["SUPPORT", "FRONT_DEF"],
		["ASSASSIN", "BACK_WEAK"],
		["MAGE", "FRONT_MELEE"],
		["ARCHER", "FRONT_MELEE"],
		["RANGED", "FRONT_MELEE"]
	]
	for item in cases:
		_expect(_first_target(str(item[0]), opponents) == str(item[1]), "role %s chooses %s" % [item[0], item[1]])

	var explicit: Array = _enemy_team()
	explicit[0]["row"] = "BACK"  # Override a natural front role
	explicit[3]["row"] = "FRONT" # Override a natural back role
	_expect(_first_target("ASSASSIN", explicit) == "FRONT_MELEE", "explicit backline overrides role inference")
	_expect(_first_target("MAGE", explicit) == "BACK_WEAK", "explicit frontline overrides role inference")

	var inferred: Array = [
		_unit("FRONT", "DEFENDER", 300),
		_unit("BACK", "RANGED", 100)
	]
	_expect(_first_target("WARRIOR", inferred) == "FRONT", "role-based row inference without explicit row")
	_expect(_first_target("ASSASSIN", inferred) == "BACK", "assassin inferred backline")
	_expect(_first_target("ASSASSIN", [_unit("ONLY_FRONT", "TANK", 100)]) == "ONLY_FRONT", "role fallback when backline absent")

func _test_frontline_depletion() -> void:
	var hero: Dictionary = _unit("WARRIOR", "WARRIOR", 100000, 2000)
	hero["atk"] = 100000
	var battle = Battle.new()
	battle.setup([hero], _enemy_team(), 123)
	var state: Dictionary = battle.step_ticks(3)
	var events: Array = state["recent_events"]
	_expect(events.size() == 3, "three attacks are emitted for frontline depletion")
	if events.size() == 3:
		var ids: Array[String] = []
		for event in events:
			ids.append(str(event.get("target_id", "")))
		_expect(ids == ["FRONT_DEF", "FRONT_MELEE", "BACK_RANGE"], "front row clears before back row")
	_expect(str(state["enemies"][0].get("row", "")) == "FRONT" and str(state["enemies"][2].get("row", "")) == "BACK", "formation stored in runtime units")
	_expect(not _enemy_team()[0].has("threat"), "fixture input not mutated")

func _test_threat_and_taunt() -> void:
	var defenders: Array = [
		_unit("TANK", "TANK", 100000, 1, "FRONT"),
		_unit("WARRIOR", "WARRIOR", 100000, 1, "FRONT"),
		_unit("MAGE", "MAGE", 100000, 1, "BACK")
	]
	var enemy: Array = [_unit("ENEMY", "MELEE", 100000, 2000, "FRONT")]
	var basic = Battle.new()
	basic.setup(defenders, enemy, 7)
	_expect(_last_target_after(basic, 1) == "TANK", "base tank threat outranks warrior")

	var boost = Battle.new()
	boost.setup(defenders, enemy, 7)
	if boost.has_method("add_threat"):
		_expect(bool(boost.call("add_threat", "ally", "WARRIOR", 200)), "threat hook accepts valid actor")
		_expect(not bool(boost.call("add_threat", "ally", "MISSING", 200)), "missing actor cannot gain threat")
		_expect(not bool(boost.call("add_threat", "ally", "WARRIOR", -1)), "negative threat change rejected")
		_expect(_last_target_after(boost, 1) == "WARRIOR", "injected threat changes target")
	else:
		_expect(false, "add_threat hook exists")

	var timed = Battle.new()
	timed.setup(defenders, enemy, 7)
	if timed.has_method("apply_taunt"):
		_expect(bool(timed.call("apply_taunt", "ally", "MAGE", 3)), "taunt accepts backline caster")
		_expect(not bool(timed.call("apply_taunt", "ally", "MISSING", 3)), "invalid taunt id rejected")
		_expect(not bool(timed.call("apply_taunt", "ally", "MAGE", 0)), "zero-duration taunt rejected")
		_expect(_last_target_after(timed, 1) == "MAGE", "taunt overrides front row at tick 1")
		_expect(_last_target_after(timed, 1) == "MAGE", "taunt holds until exclusive deadline")
		_expect(_last_target_after(timed, 1) == "TANK", "taunt expires at exact boundary tick 3")
	else:
		_expect(false, "apply_taunt hook exists")

	var dead = Battle.new()
	var fragile: Array = defenders.duplicate(true)
	fragile[2]["hp"] = 1
	var lethal: Array = enemy.duplicate(true)
	lethal[0]["atk"] = 100000
	dead.setup(fragile, lethal, 7)
	if dead.has_method("apply_taunt"):
		_expect(bool(dead.call("apply_taunt", "ally", "MAGE", 20)), "taunt can be applied before killing blow")
		_expect(_last_target_after(dead, 1) == "MAGE", "taunter first absorbs attack")
		_expect(_last_target_after(dead, 1) == "TANK", "dead taunter loses priority")
	else:
		_expect(false, "dead-taunter hook exists")

	var fighter: Dictionary = _unit("FIGHTER", "WARRIOR", 100000, 2000)
	var dealt = Battle.new()
	dealt.setup([fighter], [_unit("DUMMY", "MELEE", 100000, 1)], 2)
	var old: Dictionary = dealt.snapshot()
	var current: Dictionary = dealt.step_ticks(1)
	_expect(int(current["allies"][0].get("threat", -1)) > int(old["allies"][0].get("threat", -1)), "basic attack increases attacker threat")

func _last_target_after(battle: Variant, ticks: int) -> String:
	battle.step_ticks(ticks)
	return _last_target(battle)

func _test_replay() -> void:
	var opponents: Array = _enemy_team()
	var party: Array = [
		_unit("TANK", "TANK", 100000, 100, "FRONT"),
		_unit("ASSASSIN", "ASSASSIN", 100000, 120, "BACK")
	]
	var a = Battle.new()
	var b = Battle.new()
	a.setup(party, opponents, 435)
	b.setup(party, opponents, 435)
	if a.has_method("apply_taunt") and b.has_method("apply_taunt"):
		a.call("apply_taunt", "enemy", "BACK_WEAK", 30)
		b.call("apply_taunt", "enemy", "BACK_WEAK", 30)
	if a.has_method("add_threat") and b.has_method("add_threat"):
		a.call("add_threat", "enemy", "FRONT_MELEE", 500)
		b.call("add_threat", "enemy", "FRONT_MELEE", 500)
	var before: Array = opponents.duplicate(true)
	var one: Dictionary = a.step_ticks(90)
	for _i in range(30):
		b.advance_frame(3)
	_expect(one == b.snapshot(), "same seed/threat/taunt yields same results at 1x and 3x")
	_expect(opponents == before, "runtime never mutates source dictionaries")

func _expect(condition: bool, title: String) -> void:
	if not condition:
		failures.append(title)
