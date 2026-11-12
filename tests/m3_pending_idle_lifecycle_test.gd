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
	# Real sequence: stage 1 background at T0, resumed an hour later but
	# player viewed another page and did not claim. OS pause again.
	var second_pause: Dictionary = controller.mark_background(T0 + 3600)
	_check(not bool(second_pause["ok"]) and second_pause["reason"] == "pending_unclaimed", "pending reward must prevent resetting its anchor")
	_check(int(controller.snapshot()["offline_checkpoint"]["last_exit_unix"]) == T0, "unclaimed original time preserved")
	var two_hours: Dictionary = controller.preview_idle(T0 + 7200)
	_check(bool(two_hours["ok"]) and int(two_hours["rewards"]["gold"]) == 320, "two-hour reward retained across repeat pause")
	var collect: Dictionary = controller.claim_idle(T0 + 7200)
	_check(bool(collect["ok"]), "original checkpoint can be claimed once")
	_check(int(controller.snapshot()["economy_state"]["wallet"]["gold"]) == 320, "full accumulated gold received")
	_check(not bool(controller.claim_idle(T0 + 7200)["ok"]), "no immediate repeat claim")
	# After a successful claim in *this* session, a new background should
	# start a fresh idle interval at the actual pause time.
	var active_claim: Dictionary = controller.claim_idle(T0 + 10800)
	_check(not bool(active_claim["ok"]) and active_claim["reason"] == "awaiting_background", "no passive rewards while still active after claim")
	var fresh: Dictionary = controller.mark_background(T0 + 7260)
	_check(bool(fresh["ok"]), "fresh checkpoint accepted after just-collected reward")
	_check(int(controller.snapshot()["offline_checkpoint"]["last_exit_unix"]) == T0 + 7260, "post-claim actual exit timestamp")
	var repeated: Dictionary = controller.mark_background(T0 + 7290)
	_check(not bool(repeated["ok"]) and repeated["reason"] == "pending_unclaimed", "second suspend cannot wipe a newly pending interval")
	_check(int(controller.snapshot()["offline_checkpoint"]["last_exit_unix"]) == T0 + 7260, "repeated suspend cannot reset pending interval")
	var restart := Model.new()
	_check(bool(restart.initialize(PATH)["ok"]), "separate app process-style controller reload")
	_check(not bool(restart.mark_background(T0 + 7300)["ok"]), "new controller preserves pre-existing unpaid checkpoint")
	var next: Dictionary = restart.claim_idle(T0 + 10860)
	_check(bool(next["ok"]) and int(restart.snapshot()["economy_state"]["wallet"]["gold"]) == 480, "another hour yields exactly one more stage-1 gold grant")
	_check(restart.snapshot()["economy_state"]["seen_events"].has("offline:1700000000"), "old receipt kept")
	_check(restart.snapshot()["economy_state"]["seen_events"].has("offline:1700007260"), "new receipt kept")
	_finish()

func _check(valid: bool, label: String) -> void:
	if not valid:
		errors.append(label)

func _finish() -> void:
	if errors.is_empty():
		print("M3 REAL-DEVICE GATE PASS: unclaimed checkpoint survives repeated pause, reload and one-time payment")
		quit(0)
		return
	for label in errors:
		push_error("M3 REAL-DEVICE GATE FAIL: " + label)
	quit(1)
