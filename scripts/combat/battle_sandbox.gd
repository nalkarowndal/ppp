extends RefCounted
## M1 debug-only turn sandbox: NOT the M2 real-time automatic combat engine.
const Damage = preload("res://scripts/combat/damage_calculator.gd")
var _rng := RandomNumberGenerator.new()
var _heroes: Array = []
var _enemy: Dictionary = {}
var _turn := 0
var _finished := false

func setup(character_data: Array, enemy_data: Dictionary, seed: int = 42) -> void:
	_rng.seed = seed
	_heroes.clear()
	for source in character_data:
		if typeof(source) != TYPE_DICTIONARY:
			continue
		var stats: Dictionary = source.get("base_stats", {})
		_heroes.append({
			"name": str(source.get("name", "?")),
			"hp": int(stats.get("hp", 1)),
			"max_hp": int(stats.get("hp", 1)),
			"atk": int(stats.get("atk", 1)),
			"def": int(stats.get("def", 0)),
			"crit": float(stats.get("crit", 0.0))
		})
	_enemy = {
		"name": str(enemy_data.get("name", "Enemy")),
		"hp": int(enemy_data.get("hp", 200)),
		"max_hp": int(enemy_data.get("hp", 200)),
		"atk": int(enemy_data.get("atk", 35)),
		"def": int(enemy_data.get("def", 10))
	}
	_turn = 0
	_finished = false

func step() -> Dictionary:
	if _finished:
		return snapshot()
	_turn += 1
	for i in range(_heroes.size()):
		var hero: Dictionary = _heroes[i]
		if int(hero["hp"]) <= 0 or int(_enemy["hp"]) <= 0:
			continue
		var crit_multiplier := 1.5 if _rng.randf() < float(hero["crit"]) else 1.0
		var dealt: int = Damage.calculate(float(hero["atk"]), 1.0, float(_enemy["def"]), 1.0, crit_multiplier, _rng.randf_range(0.95, 1.05))
		_enemy["hp"] = maxi(0, int(_enemy["hp"]) - dealt)
	if int(_enemy["hp"]) > 0:
		var targets: Array[int] = []
		for i in range(_heroes.size()):
			if int(_heroes[i]["hp"]) > 0:
				targets.append(i)
		if not targets.is_empty():
			var target_index: int = targets[_rng.randi_range(0, targets.size() - 1)]
			var target: Dictionary = _heroes[target_index]
			var received: int = Damage.calculate(float(_enemy["atk"]), 1.0, float(target["def"]))
			target["hp"] = maxi(0, int(target["hp"]) - received)
			_heroes[target_index] = target
	var living := 0
	for hero in _heroes:
		if int(hero["hp"]) > 0:
			living += 1
	_finished = int(_enemy["hp"]) <= 0 or living == 0
	return snapshot()

func snapshot() -> Dictionary:
	var state := "running"
	if _finished:
		state = "victory" if int(_enemy["hp"]) <= 0 else "defeat"
	return {"turn": _turn, "state": state, "heroes": _heroes.duplicate(true), "enemy": _enemy.duplicate(true)}
