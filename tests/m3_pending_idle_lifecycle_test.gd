extends SceneTree
## M3 approval blocker regression: Android HOME -> resume without claim ->
## HOME must NOT wipe earlier unclaimed idle checkpoint.
const Repo = preload("res://scripts/core/data_repository.gd")
const Gear = preload("res://scripts/core/equipment_system.gd")
const Idle = preload("res://scripts/core/offline_rewards.gd")
const Store = preload("res://scripts/core/profile_store.gd")
const Model = preload("res://scripts/ui/m3_progression_controller.gd")

const T0: int = 1700000000
const PATH: String = "user://qa_m3_gate/pending_idle.json"
var errors: Array[String] = []

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("user://qa_m3_gate")
	for file in [PATH, PATH + ".bak", PATH + ".tmp", PATH + ".bak.tmp"]:
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)
	var chars: Array = Repo.load_array("res://data/characters.json")
	var catalog: Dictionary = Gear.build_catalog(Repo.load_array("res://data/equipment.json"))
	var initial: Dictionary = Store.new_profile()
	initial["offline_checkpoint"] = Idle.new_checkpoint(T0, 1)
	var first: Dictionary = Store.save_profile(initial, catalog, chars, PATH)
	_check(bool(first["ok"]), "seed checkpoint saved")
	if not bool(first["ok"]):
		_finish()
		return
	var controller := Model.new()
	_check(bool(controller.initialize(PATH)["ok"]), "controller reopened checkpoint")
	_check(bool(controller.mark_foreground(T0 + 3600)["ok"]), "legacy checkpoint settled on cold start")
	var frozen: Dictionary = controller.preview_idle(T0 + 7200)
	_check(bool(frozen["ok"]) and int(frozen["rewards"]["gold"]) == 160, "foreground time cannot inflate reward")
	_check(bool(controller.mark_background(T0 + 7200)["ok"]), "second real pause starts another interval")
	_check(controller.mark_background(T0 + 9000)["reason"] == "unchanged_checkpoint", "duplicate pause keeps interval start")
	_check(not bool(controller.claim_idle(T0 + 9000)["ok"]), "cannot claim before resume")

	var restart := Model.new()
	_check(bool(restart.initialize(PATH)["ok"]), "separate controller opens paused profile")
	_check(bool(restart.mark_foreground(T0 + 10800)["ok"]), "cold start closes saved interval")
	_check(restart.mark_foreground(T0 + 14400)["reason"] == "unchanged_checkpoint", "duplicate resume cannot grow reward")
	var combined: Dictionary = restart.preview_idle(T0 + 14400)
	_check(bool(combined["ok"]) and int(combined["credited_seconds"]) == 7200, "only two actual offline hours count")
	_check(bool(restart.claim_idle(T0 + 14400)["ok"]), "combined reward claimed")
	var paid: Dictionary = restart.snapshot()
	_check(int(paid["economy_state"]["wallet"]["gold"]) == 320, "full accumulated gold received")
	_check(paid["economy_state"]["seen_events"].has("offline:1700000000"), "legacy receipt key preserved")
	_check(paid["offline_checkpoint"].is_empty(), "claim and checkpoint consumption persisted together")

	_check(bool(controller.initialize(PATH)["ok"]), "reload claimed profile")
	_check(bool(controller.mark_foreground(T0 + 18000)["ok"]), "cold start without a checkpoint")
	_check(not bool(controller.claim_idle(T0 + 18000)["ok"]), "reopening cannot grant a duplicate reward")
	_check(bool(controller.mark_background(T0 + 18000)["ok"]), "fresh pause after claim")
	_check(bool(controller.mark_foreground(T0 + 17999)["ok"]), "clock rollback closes interval safely")
	var rolled_back: Dictionary = controller.preview_idle(T0 + 18001)
	_check(bool(rolled_back["ok"]) and int(rolled_back["credited_seconds"]) == 0, "clock rollback adds zero time")
	_check(bool(controller.mark_background(T0 + 18000)["ok"]), "next valid pause accepted")
	_check(bool(controller.mark_foreground(T0 + 54000)["ok"]), "long interval closed")
	var capped: Dictionary = controller.preview_idle(T0 + 55000)
	_check(bool(capped["ok"]) and int(capped["credited_seconds"]) == 28800, "sum still capped at eight hours")
	_check(bool(controller.claim_idle(T0 + 55000)["ok"]), "second payout succeeds")
	_check(int(controller.snapshot()["economy_state"]["wallet"]["gold"]) == 1600, "second payout added exactly once")
	_check(controller.snapshot()["economy_state"]["seen_events"].size() == 2, "two distinct durable receipts")
	var legacy_after_claim: Dictionary = controller.snapshot()
	legacy_after_claim["offline_checkpoint"] = Idle.new_checkpoint(T0 + 55000, 1)
	_check(bool(Store.save_profile(legacy_after_claim, catalog, chars, PATH)["ok"]), "legacy post-claim save fixture")
	_check(bool(restart.initialize(PATH)["ok"]), "legacy post-claim save opens")
	_check(bool(restart.mark_foreground(T0 + 58600)["ok"]), "ambiguous legacy anchor is retired")
	_check(not bool(restart.claim_idle(T0 + 58600)["ok"]), "legacy claim time cannot create a payout")
	_check(int(restart.snapshot()["economy_state"]["wallet"]["gold"]) == 1600, "legacy migration preserves wallet")
	_finish()

func _check(valid: bool, label: String) -> void:
	if not valid:
		errors.append(label)

func _finish() -> void:
	if errors.is_empty():
		print("M3 IDLE LIFECYCLE PASS: unclaimed checkpoint survives repeated pause, reload and one-time payment")
		quit(0)
		return
	for label in errors:
		push_error("M3 IDLE LIFECYCLE FAIL: " + label)
	quit(1)
