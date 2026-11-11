extends SceneTree
## M2-3: data-driven active / ultimate combat behavior contracts.
const Battle = preload("res://scripts/combat/auto_battle_core.gd")
const Repo = preload("res://scripts/core/data_repository.gd")
var failures: Array[String] = []

func _initialize() -> void:
	var skills: Array = Repo.load_array("res://data/skills.json")
	var heroes: Array = Repo.load_array("res://data/characters.json")
	_check(skills.size() == 16 and heroes.size() == 8, "16 skills and 8 heroes exist")
	var before: Array = skills.duplicate(true)
	var probe = Battle.new()
	if not probe.has_method("configure_skills"):
		_check(false, "M2-3 skill catalogue and execution API exists")
		_finish()
		return
	_check(not probe.configure_skills([skills[0], skills[0]]), "duplicate IDs rejected")
	_check(probe.configure_skills(skills), "valid 16-skill catalogue configured")
	_check(skills == before, "catalogue config must not mutate source")
	_test_all_sixteen(skills, heroes)
	_test_cooldown_and_energy(skills)
	_test_manual_ultimate(skills)
	_test_defense(skills)
	_test_determinism(skills)
	_test_target_limits_and_healing(skills)
	_test_exact_cooldown_boundary(skills)
	_finish()

func _unit(id: String, role: String, hp: int, atk: int = 50, spd: int = 1) -> Dictionary:
	return {"id": id, "name": id, "role": role, "hp": hp, "atk": atk, "def": 0, "spd": spd, "crit": 0.0}

func _training_enemies() -> Array:
	return [_unit("DUMMY_A", "TANK", 1000000), _unit("DUMMY_B", "MAGE", 1000000), _unit("DUMMY_C", "RANGED", 1000000)]

func _hero_fast(hero: Dictionary) -> Dictionary:
	var copy: Dictionary = hero.duplicate(true)
	copy["base_stats"]["spd"] = 2000
	copy["base_stats"]["crit"] = 0.0
	return copy

func _events(state: Dictionary, event_type: String) -> Array:
	var matches: Array = []
	for event in state["recent_events"]:
		if str(event.get("type", "")) == event_type:
			matches.append(event)
	return matches

func _test_all_sixteen(skills: Array, heroes: Array) -> void:
	for hero in heroes:
		var b = Battle.new()
		_check(b.configure_skills(skills), "catalogue loads for %s" % hero["id"])
		b.setup([_hero_fast(hero)], _training_enemies(), 71)
		var state: Dictionary = b.step_ticks(1)
		var active: Array = _events(state, "skill_cast")
		_check(active.size() == 1 and str(active[0].get("skill_id", "")) == str(hero["skill_ids"][0]), "%s uses its active" % hero["id"])
		if active.is_empty():
			continue
		state = b.step_ticks(19)
		var casts: Array = _events(state, "skill_cast")
		var active_count: int = 0
		var ultimate_count: int = 0
		for event in casts:
			if str(event.get("skill_id", "")) == str(hero["skill_ids"][0]):
				active_count += 1
			if str(event.get("skill_id", "")) == str(hero["skill_ids"][1]):
				ultimate_count += 1
		_check(active_count == 1, "%s active cooldown prevents recast" % hero["id"])
		_check(ultimate_count == 1, "%s ultimate auto cast at 100 energy" % hero["id"])
		_check(int(state["allies"][0]["energy"]) < 100, "%s ultimate consumed full energy" % hero["id"])
		_check(int(state["allies"][0]["next_active_tick"]) > 1, "%s cooldown stored in ticks" % hero["id"])
		if str(hero["id"]) == "CHR_RIA":
			_check(_events(state, "skill_hit").size() >= 6, "Ria multi-hit and chain attacks resolved")
		if str(hero["id"]) == "CHR_BELL":
			_check(int(state["allies"][0]["shield"]) > 0, "Bell shield persists in runtime")
		if str(hero["id"]) == "CHR_LEON":
			_check(int(state["allies"][0]["shield"]) > 0, "Leon shield persists in runtime")
		if str(hero["id"]) == "CHR_LUNA":
			_check(_events(state, "heal").size() >= 1, "Luna heal resolves at cast")
		if str(hero["id"]) == "CHR_ARIA":
			_check(_events(state, "skill_cast")[0].get("deferred_effect", "") == "BURN", "burn marker explicitly deferred")

func _test_cooldown_and_energy(skills: Array) -> void:
	var actor: Dictionary = _unit("COOL", "WARRIOR", 100000, 25, 2000)
	actor["skill_ids"] = ["SKL_ARIA_ACTIVE", "SKL_ARIA_ULTIMATE"]
	var b = Battle.new()
	b.configure_skills(skills)
	b.setup([actor], _training_enemies(), 19)
	var one: Dictionary = b.step_ticks(1)
	_check(int(one["allies"][0].get("next_active_tick", 0)) == 161, "8s cooldown is 160 ticks after tick 1")
	var two: Dictionary = b.step_ticks(1)
	_check(_events(two, "basic_attack").size() == 1, "cooldown falls back to basic")
	_check(int(two["allies"][0]["energy"]) == 20, "active then basic gains 10 energy each")
	var manual = Battle.new()
	manual.configure_skills(skills)
	manual.setup([actor], _training_enemies(), 19)
	_check(manual.has_method("set_auto_ultimates"), "auto ultimate policy API")
	_check(manual.has_method("request_ultimate"), "manual ultimate queue API")

func _test_manual_ultimate(skills: Array) -> void:
	var actor: Dictionary = _unit("MANUAL", "WARRIOR", 100000, 25, 2000)
	actor["skill_ids"] = ["SKL_ARIA_ACTIVE", "SKL_ARIA_ULTIMATE"]
	var b = Battle.new()
	b.configure_skills(skills)
	b.setup([actor], _training_enemies(), 91)
	b.set_auto_ultimates(false)
	var state: Dictionary = b.step_ticks(11)
	_check(_events(state, "skill_cast").size() == 1, "auto-off does not consume full ultimate gauge")
	_check(int(state["allies"][0]["energy"]) == 100, "energy capped at 100 in manual mode")
	_check(b.request_ultimate("ally", "MANUAL"), "manual request accepted for alive hero")
	_check(not b.request_ultimate("ally", "MANUAL"), "duplicate manual queue rejected")
	_check(not b.request_ultimate("ally", "MISSING"), "invalid manual request rejected")
	state = b.step_ticks(1)
	var casts: Array = _events(state, "skill_cast")
	_check(casts.size() == 2 and str(casts[-1].get("category", "")) == "ULTIMATE", "queued ultimate executes on next action")
	_check(int(state["allies"][0]["energy"]) == 0, "manual ultimate drains energy")
	_check(not bool(state["allies"][0].get("ultimate_requested", true)), "manual queue consumed")

func _test_defense(skills: Array) -> void:
	var le = _unit("DEFENDER", "TANK", 100000, 40, 2000)
	le["skill_ids"] = ["SKL_LEON_ACTIVE", "SKL_LEON_ULTIMATE"]
	var enemy = _unit("ATTACKER", "MELEE", 100000, 1, 2000)
	var b = Battle.new()
	b.configure_skills(skills)
	b.setup([le], [enemy], 51)
	var state: Dictionary = b.step_ticks(1)
	_check(int(state["allies"][0]["shield"]) > 0, "Leon active produces shield")
	_check(int(state["allies"][0]["hp"]) == 100000, "shield absorbs initial attack before HP")

func _test_determinism(skills: Array) -> void:
	var actor: Dictionary = _unit("REPLAY", "ARCHER", 100000, 30, 2000)
	actor["skill_ids"] = ["SKL_RIA_ACTIVE", "SKL_RIA_ULTIMATE"]
	var a = Battle.new()
	var b = Battle.new()
	a.configure_skills(skills)
	b.configure_skills(skills)
	a.setup([actor], _training_enemies(), 555)
	b.setup([actor], _training_enemies(), 555)
	var one: Dictionary = a.step_ticks(40)
	for i in range(20):
		b.advance_frame(2)
	_check(one == b.snapshot(), "skill RNG/cooldowns/replay same at 1x and 2x")

func _test_target_limits_and_healing(skills: Array) -> void:
	var serena: Dictionary = _unit("SERENA", "MAGE", 100000, 120, 2000)
	serena["skill_ids"] = ["SKL_SERENA_ACTIVE", "SKL_SERENA_ULTIMATE"]
	var enemies: Array = _training_enemies()
	enemies.append(_unit("DUMMY_D", "MAGE", 1000000))
	var b = Battle.new()
	b.configure_skills(skills)
	b.setup([serena], enemies, 31)
	var state: Dictionary = b.step_ticks(1)
	_check(_events(state, "skill_hit").size() == 3, "up-to-three active hits exactly three targets")
	state = b.step_ticks(10)
	_check(_events(state, "skill_hit").size() == 7, "all-enemy ultimate hits all four living enemies")

	var luna: Dictionary = _unit("LUNA", "SUPPORT", 850, 92, 1000)
	luna["skill_ids"] = ["SKL_LUNA_ACTIVE", "SKL_LUNA_ULTIMATE"]
	var tank: Dictionary = _unit("FRONT", "TANK", 5000, 1, 1)
	var enemy: Dictionary = _unit("TRAINING_ATTACKER", "MELEE", 1000000, 200, 2000)
	var healer = Battle.new()
	healer.configure_skills(skills)
	healer.setup([tank, luna], [enemy], 37)
	var after_first: Dictionary = healer.step_ticks(1)
	var damaged_hp: int = int(after_first["allies"][0]["hp"])
	var after_heal: Dictionary = healer.step_ticks(1)
	var heal_events: Array = _events(after_heal, "heal")
	_check(heal_events.size() == 1, "Luna actively heals injured ally")
	if heal_events.size() == 1:
		_check(str(heal_events[0]["target_id"]) == "FRONT" and int(heal_events[0]["amount"]) > 0, "lowest HP ratio ally receives heal")
	_check(int(after_heal["allies"][0]["hp"]) > damaged_hp and int(after_heal["allies"][0]["hp"]) <= 5000, "heal restores actual HP without overhealing")

	var bell: Dictionary = _unit("BELL", "TANK", 100000, 1, 2000)
	bell["skill_ids"] = ["SKL_BELL_ACTIVE", "SKL_BELL_ULTIMATE"]
	var taunter = Battle.new()
	taunter.configure_skills(skills)
	taunter.setup([bell], _training_enemies(), 13)
	var taunted: Dictionary = taunter.step_ticks(1)
	_check(int(taunted["allies"][0]["taunt_until_tick"]) == 61, "Bell active applies 60-tick taunt")
	var casts: Array = _events(taunted, "skill_cast")
	_check(not casts.is_empty() and str(casts[0].get("deferred_effect", "")) == "DEF_UP", "Bell DEF buff remains deferred to M2-4")

func _test_exact_cooldown_boundary(skills: Array) -> void:
	var actor: Dictionary = _unit("CD", "WARRIOR", 100000, 1, 2000)
	actor["skill_ids"] = ["SKL_ARIA_ACTIVE", "SKL_ARIA_ULTIMATE"]
	var battle = Battle.new()
	battle.configure_skills(skills)
	battle.setup([actor], _training_enemies(), 91)
	battle.set_auto_ultimates(false)
	var state: Dictionary = battle.step_ticks(160)
	_check(int(state["allies"][0]["next_active_tick"]) == 161, "8s active unavailable before tick 161")
	state = battle.step_ticks(1)
	var cast: Array = _events(state, "skill_cast")
	_check(cast.size() == 1 and int(cast[0]["tick"]) == 161, "active becomes available exactly on tick 161")
	_check(int(state["allies"][0]["next_active_tick"]) == 321, "successful recast starts a new 160-tick cooldown")

func _check(ok: bool, label: String) -> void:
	if not ok:
		failures.append(label)

func _finish() -> void:
	if not failures.is_empty():
		for label in failures:
			push_error("M2-3 FAIL: " + label)
		quit(1)
		return
	print("M2-3 SKILLS PASS: 16 casts, cooldown, energy, manual ultimate, shield, replay")
	quit(0)
