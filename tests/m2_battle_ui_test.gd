extends SceneTree
## M2-5 Godot scene integration tests (headless interaction, not visual or device QA).
const BattleScene = preload("res://scenes/battle_m2_5.tscn")
const MainScene = preload("res://scenes/main.tscn")
const Repo = preload("res://scripts/core/data_repository.gd")
var _errors: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var page: Control = BattleScene.instantiate()
	root.add_child(page)
	page.set_process(false)
	await process_frame
	var status: Label = page.find_child("BattleStatus", true, false)
	var allies: Control = page.find_child("AllyCards", true, false)
	var enemies: Control = page.find_child("EnemyCards", true, false)
	var log: Label = page.find_child("CombatLog", true, false)
	var speed: Button = page.find_child("SpeedButton", true, false)
	var auto: Button = page.find_child("AutoButton", true, false)
	var restart: Button = page.find_child("RestartButton", true, false)
	var back: Button = page.find_child("BackButton", true, false)
	var less_motion: Button = page.find_child("ReducedMotionButton", true, false)
	_check(status != null and allies != null and enemies != null and log != null, "HUD and battle unit cards instantiated")
	_check(speed != null and auto != null and restart != null and back != null and less_motion != null, "battle controls instantiated")
	if not _errors.is_empty():
		_finish()
		return

	var battle = page.get("_battle")
	_check(battle != null, "battle core connected to scene")
	if battle == null:
		_finish()
		return
	var initial: Dictionary = battle.snapshot()
	_check(str(initial["state"]) == "running" and initial["allies"].size() == 3 and initial["enemies"].size() == 3, "3v3 combat sourced from JSON")
	_check(allies.get_child_count() == 3 and enemies.get_child_count() == 3, "3 allies and 3 enemies rendered")
	_check(str(status.text).contains("전투"), "Korean battle title present: " + str(status.text))
	_check(page.theme.default_font != null and page.theme.default_font.has_char(0xD55C), "Korean font glyph available")
	var source: Array = Repo.load_array("res://data/characters.json")
	_check(str(initial["allies"][0]["id"]) == str(source[0]["id"]), "player roster retains JSON IDs")

	speed.pressed.emit()
	_check(int(page.get("_speed")) == 2 and speed.text.contains("2"), "speed toggle to 2x")
	speed.pressed.emit()
	_check(int(page.get("_speed")) == 3 and speed.text.contains("3"), "speed toggle to 3x")
	speed.pressed.emit()
	_check(int(page.get("_speed")) == 1, "speed wraps to 1x")
	auto.pressed.emit()
	_check(not bool(page.get("_auto_ultimates")) and auto.text.contains("OFF"), "AUTO OFF disables ultimate auto-cast")
	less_motion.pressed.emit()
	_check(bool(page.get("_reduced_motion")), "reduced motion toggle works")

	var enemy_id: String = str(initial["enemies"][0]["id"])
	_check(battle.add_status("enemy", enemy_id, "BURN", 60), "inject visible burn into running combat")
	page.call("refresh_view")
	var enemy_card: Node = enemies.get_child(0)
	var status_text: Label = enemy_card.find_child("StatusText", true, false)
	_check(status_text != null and str(status_text.text).contains("화상"), "actual BURN status and Korean label appear in HUD")
	_check(not str(status_text.text).contains("0.0초"), "active status remaining time positive")
	var snapshot_before: Dictionary = battle.snapshot()
	page.call("advance_ticks", 20)
	_check(int(battle.snapshot()["ticks"]) == int(snapshot_before["ticks"]) + 20, "presenter advances exact 20 logical ticks")
	_check(str(log.text).contains("화상") or str(log.text).contains("공격") or str(log.text).contains("스킬"), "combat log reflects runtime events")
	_check(int(battle.snapshot()["enemies"][0]["hp"]) < int(snapshot_before["enemies"][0]["hp"]), "battle clock advances damage/status runtime")
	var ult_button: Button = allies.get_child(0).find_child("UltimateButton", true, false)
	_check(ult_button != null and ult_button.disabled, "manual ultimate unavailable before full energy")

	page.call("advance_ticks", 180)
	var full: Dictionary = battle.snapshot()
	var available: bool = full["state"] == "running" and int(full["allies"][0]["hp"]) > 0 and int(full["allies"][0]["energy"]) >= 100
	_check(available, "preview encounter survives long enough for 100-energy manual ultimate")
	if available:
		ult_button = allies.get_child(0).find_child("UltimateButton", true, false)
		_check(not ult_button.disabled, "manual ultimate enabled at 100 energy")
		ult_button.pressed.emit()
		_check(bool(battle.snapshot()["allies"][0]["ultimate_requested"]), "ultimate button queues request into M2-3 core")
		page.call("advance_ticks", 30)
		var casted: bool = false
		for event in battle.snapshot()["recent_events"]:
			if event.get("type") == "skill_cast" and event.get("actor_id") == full["allies"][0]["id"] and event.get("category") == "ULTIMATE":
				casted = true
		_check(casted, "queued ultimate cast appears in actual combat events")

	restart.pressed.emit()
	var again: Dictionary = page.get("_battle").snapshot()
	_check(again["state"] == "running" and int(again["ticks"]) == 0, "restart resets battle deterministically")
	_check(allies.get_child_count() == 3 and enemies.get_child_count() == 3, "restart keeps unit cards without duplicates")
	page.queue_free()
	await process_frame

	var main: Control = MainScene.instantiate()
	root.add_child(main)
	await process_frame
	var launcher: Button = null
	for child in main.find_children("*", "Button", true, false):
		if child.text.contains("M2-5"):
			launcher = child
			break
	_check(launcher != null, "M1 debug screen keeps legacy controls and offers M2-5 entry")
	_check(_has_button(main, "1턴 진행 (디버그)") and _has_button(main, "샌드박스 턴 번호 저장"), "M1 STEP/SAVE controls remain available")
	main.queue_free()
	await process_frame
	_finish()

func _has_button(root_node: Node, value: String) -> bool:
	for child in root_node.find_children("*", "Button", true, false):
		if child.text == value:
			return true
	return false

func _check(ok: bool, msg: String) -> void:
	if not ok:
		_errors.append(msg)

func _finish() -> void:
	if _errors.is_empty():
		print("M2-5 BATTLE UI PASS: scene 3v3, HUD, Hangul, AUTO, speed, status, ultimate, restart, M1 isolation")
		quit(0)
	else:
		for err in _errors:
			push_error("M2-5 FAIL: " + err)
		quit(1)
