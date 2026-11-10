extends SceneTree
## M2-1 core regression suite. Run after importing resources:
## godot --headless --path . --script res://tests/m2_combat_core_test.gd
const Repo = preload("res://scripts/core/data_repository.gd")
const Battle = preload("res://scripts/combat/auto_battle_core.gd")

var failures: Array[String] = []

func _initialize() -> void:
	var heroes: Array = Repo.load_array("res://data/characters.json")
	var enemies: Array = Repo.load_array("res://data/enemies.json")
	_expect(heroes.size() == 8 and enemies.size() == 3, "fixture data exists")
	if heroes.size() < 5 or enemies.size() < 3:
		_finish()
		return

	var a = Battle.new()
	a.setup(heroes.slice(0, 3), enemies, 731)
	var initial: Dictionary = a.snapshot()
	_expect(str(initial["state"]) == "running", "valid battle starts")
	_expect(initial["allies"].size() == 3 and initial["enemies"].size() == 3, "3v3 deployed")
	_expect(int(initial["ticks"]) == 0, "no ticks consumed during setup")
	var after: Dictionary = a.step_ticks(150)
	_expect(int(after["ticks"]) > 0, "combat time advances")
	_expect(after["recent_events"].size() > 0, "basic attacks emitted")
	_expect(int(after["allies"][0]["max_hp"]) == 950, "source stats loaded")
	_expect(int(heroes[0]["base_stats"]["hp"]) == 950, "original JSON never mutated")

	var replay = Battle.new()
	replay.setup(heroes.slice(0, 3), enemies, 731)
	var matching: Dictionary = replay.step_ticks(150)
	_expect(matching == after, "same seed produces identical action log and state")

	var speed_one = Battle.new()
	speed_one.setup(heroes.slice(0, 5), enemies, 731)
	var speed_two = Battle.new()
	speed_two.setup(heroes.slice(0, 5), enemies, 731)
	var speed_three = Battle.new()
	speed_three.setup(heroes.slice(0, 5), enemies, 731)
	var single: Dictionary = speed_one.step_ticks(60)
	for _i in range(30):
		speed_two.advance_frame(2)
	for _i in range(20):
		speed_three.advance_frame(3)
	_expect(single == speed_two.snapshot() and single == speed_three.snapshot(), "1x/2x/3x equivalent at equal ticks")
	_expect(single["allies"].size() == 5, "full 5-hero roster supported")

	var target_battle = Battle.new()
	target_battle.setup([heroes[0]], enemies, 7)
	var first: Dictionary = target_battle.step_ticks(20)
	_expect(not first["recent_events"].is_empty(), "first auto attack occurred")
	if not first["recent_events"].is_empty():
		_expect(str(first["recent_events"][0]["target_id"]) == "ENM_FOREST_GUARD", "defender targeted before other foes")

	var win = Battle.new()
	win.setup([{"id": "TEST_HERO", "name": "Test", "hp": 1000, "atk": 100000, "def": 0, "spd": 200}], [{"id": "TEST_ENEMY", "name": "Weak", "hp": 1, "atk": 1, "def": 0, "spd": 1}], 9)
	var won: Dictionary = win.step_ticks(100)
	_expect(str(won["state"]) == "victory", "elimination produces victory")
	var win_ticks: int = int(won["ticks"])
	_expect(int(win.step_ticks(500)["ticks"]) == win_ticks, "completed battle stops ticking")

	var tanky_hero: Dictionary = {"id": "H", "name": "Hero", "hp": 1000000, "atk": 1, "def": 100000, "spd": 1}
	var tanky_enemy: Dictionary = {"id": "E", "name": "Enemy", "hp": 1000000, "atk": 1, "def": 100000, "spd": 1}
	var timed = Battle.new()
	timed.setup([tanky_hero], [tanky_enemy], 17)
	var timed_state: Dictionary = timed.step_ticks(1900)
	_expect(str(timed_state["state"]) == "defeat" and int(timed_state["ticks"]) == 1800, "90-second timeout")
	var boss = Battle.new()
	boss.setup([tanky_hero], [tanky_enemy], 17, true)
	var boss_state: Dictionary = boss.step_ticks(1900)
	_expect(str(boss_state["state"]) == "running" and int(boss_state["ticks"]) == 1900, "boss uses 120-second limit")
	var boss_timeout: Dictionary = boss.step_ticks(600)
	_expect(str(boss_timeout["state"]) == "defeat" and int(boss_timeout["ticks"]) == 2400, "120-second boss timeout")

	var invalid = Battle.new()
	invalid.setup(heroes, [])
	_expect(str(invalid.step_ticks(50)["state"]) == "invalid", "empty encounter is not a victory")
	var capped = Battle.new()
	capped.setup(heroes, enemies)
	_expect(capped.snapshot()["allies"].size() == 5, "party never exceeds planned 5 slots")
	_finish()

func _expect(condition: bool, test_name: String) -> void:
	if not condition:
		failures.append(test_name)

func _finish() -> void:
	if not failures.is_empty():
		for message in failures:
			push_error("M2-1 FAIL: " + message)
		quit(1)
		return
	print("M2-1 COMBAT PASS: seed, 3v3, 5-unit, target, speed, victory, timeouts, immutable data")
	quit(0)
