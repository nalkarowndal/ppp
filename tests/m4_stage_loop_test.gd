extends SceneTree
## M4 vertical slice: a result is never enough to pay without a real M2 victory.
const Repo = preload("res://scripts/core/data_repository.gd")
const Gear = preload("res://scripts/core/equipment_system.gd")
const Store = preload("res://scripts/core/profile_store.gd")
const Stage = preload("res://scripts/core/m4_stage_run.gd")
const PATH: String = "user://qa_m4/stage_profile.json"
var failures: Array[String] = []

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("user://qa_m4")
	for path in [PATH, PATH + ".bak", PATH + ".tmp", PATH + ".bak.tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	var runner = Stage.new()
	_assert(bool(runner.initialize(PATH).get("ok", false)), "create stage session using actual M3 profile store")
	_assert(runner.available_stages().size() == 10, "ten authored stages loaded")
	_assert(not bool(runner.settle_victory().get("ok", false)), "no battle means no rewards")
	var heroes: Array = ["CHR_ARIA", "CHR_SERENA", "CHR_LEON"]
	_assert(not bool(runner.start_stage(2, heroes).get("ok", false)), "second stage locked before stage one clear")
	_assert(not bool(runner.start_stage(1, ["CHR_ARIA", "CHR_ARIA", "CHR_LEON"]).get("ok", false)), "duplicate party character rejected")
	_assert(not bool(runner.start_stage(1, ["CHR_FAKE", "CHR_SERENA", "CHR_LEON"]).get("ok", false)), "forged hero rejected")
	_assert(bool(runner.start_stage(1, heroes).get("ok", false)), "stage one starts with M3 stats and actual M2 battle")
	_assert(not bool(runner.settle_victory().get("ok", false)), "unfinished battle cannot pay")
	_assert(_win(runner), "stage one battle actually reaches victory")
	var first: Dictionary = runner.settle_victory()
	_assert(bool(first.get("ok", false)), "real victory is durably paid")
	_assert(bool(first.get("first_clear", false)), "first clear is identifiable")
	_assert(int(first.get("rewards", {}).get("gold", 0)) >= 72, "reward enables paid growth")
	_assert(int(first.get("rewards", {}).get("xp_crystals", 0)) >= 120, "reward enables XP-based growth")
	_assert(not bool(runner.settle_victory().get("ok", false)), "same victory cannot settle twice")
	var catalog: Dictionary = Gear.build_catalog(Repo.load_array("res://data/equipment.json"))
	var chars: Array = Repo.load_array("res://data/characters.json")
	var persisted: Dictionary = Store.load_profile(PATH, catalog, chars)
	_assert(bool(persisted.get("ok", false)), "reward and progress persisted")
	if bool(persisted.get("ok", false)):
		var p: Dictionary = persisted["profile"]
		_assert(p["economy_state"]["seen_events"].has("stage:clear:001"), "first clear durable receipt")
		_assert(p["economy_state"]["inventory"].size() == 1, "stage one equipment received exactly once")
		_assert(int(p["highest_cleared_stage"]) == 1, "stage one progress saved")
	var reloaded = Stage.new()
	_assert(bool(reloaded.initialize(PATH).get("ok", false)), "new session reloads stage progress")
	_assert(bool(reloaded.start_stage(2, heroes).get("ok", false)), "stage two unlocked only after real first clear")
	_assert(not bool(reloaded.settle_victory().get("ok", false)), "stage two cannot pay before its own victory")
	_assert(bool(reloaded.start_stage(1, heroes).get("ok", false)), "cleared stage supports replay")
	_assert(_win(reloaded), "replayed stage also completes a real battle")
	var repeated: Dictionary = reloaded.settle_victory()
	_assert(bool(repeated.get("ok", false)) and not bool(repeated.get("first_clear", true)), "replay grants only repeat currency")
	persisted = Store.load_profile(PATH, catalog, chars)
	if bool(persisted.get("ok", false)):
		_assert(persisted["profile"]["economy_state"]["inventory"].size() == 1, "replay does not mint first-clear gear")
		_assert(persisted["profile"]["economy_state"]["seen_events"].size() == 2, "both victories have unique receipts")
	_assert(not bool(reloaded.start_stage(10, heroes).get("ok", false)), "stage ten cannot be skipped")
	_finish()

func _win(runner: RefCounted) -> bool:
	for _i in range(1800):
		var battle: Dictionary = runner.advance_ticks(1)
		if str(battle.get("state", "")) != "running":
			return str(battle.get("state", "")) == "victory"
	return false

func _assert(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("M4 FAIL: " + message)

func _finish() -> void:
	if failures.is_empty():
		print("M4 STAGE LOOP PASS: real victory, unlock, receipts, reward replay, durable reload")
		quit(0)
	else:
		printerr("M4 STAGE LOOP FAIL: " + str(failures))
		quit(1)
