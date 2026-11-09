extends SceneTree
## Run: godot --headless --path . --script res://tests/smoke_test.gd
const Repo = preload("res://scripts/core/data_repository.gd")
const Progression = preload("res://scripts/core/progression.gd")
const Damage = preload("res://scripts/combat/damage_calculator.gd")
const Sandbox = preload("res://scripts/combat/battle_sandbox.gd")

func _initialize() -> void:
	var characters: Array = Repo.load_array("res://data/characters.json")
	var enemies: Array = Repo.load_array("res://data/enemies.json")
	if characters.size() != 8 or enemies.is_empty():
		push_error("SMOKE FAIL: missing character/enemy data")
		quit(1)
		return
	if Progression.experience_cost(1) != 120 or Progression.experience_cost(99) != 40888:
		push_error("SMOKE FAIL: experience cost")
		quit(1)
		return
	if Damage.calculate(200.0, 1.5, 100.0, 1.15, 1.0, 1.0) != 172:
		push_error("SMOKE FAIL: damage formula")
		quit(1)
		return
	var sandbox = Sandbox.new()
	sandbox.setup(characters.slice(0, 3), enemies[0], 42)
	var original: Dictionary = sandbox.step()
	sandbox.setup(characters.slice(0, 3), enemies[0], 42)
	var replay: Dictionary = sandbox.step()
	if original != replay:
		push_error("SMOKE FAIL: seed reproducibility")
		quit(1)
		return
	print("SMOKE PASS: data, formula, reproducible sandbox")
	quit(0)
