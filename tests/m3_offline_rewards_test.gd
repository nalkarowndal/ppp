extends SceneTree
## M3-4 RED/GREEN idle rewards: capped time, fixed balance, M3-3 receipts.
const Repo = preload("res://scripts/core/data_repository.gd")
const Equipment = preload("res://scripts/core/equipment_system.gd")
const Economy = preload("res://scripts/core/economy_inventory.gd")
const Idle = preload("res://scripts/core/offline_rewards.gd")

const T0: int = 1700000000
var failures: Array[String] = []

func _initialize() -> void:
	var balance: Dictionary = Repo.load_dictionary("res://data/balance_config.json")
	var catalog: Dictionary = Equipment.build_catalog(Repo.load_array("res://data/equipment.json"))
	_expect(not balance.is_empty() and catalog.size() == 6, "M3 fixture available")
	if balance.is_empty() or catalog.size() != 6:
		_finish()
		return
	_expect(int(balance["maximum_idle_hours"]) == 8 and is_equal_approx(float(balance["offline_efficiency"]), 0.8), "existing eight hours and 80% balance untouched")

	var initial: Dictionary = Idle.new_checkpoint(T0, 1)
	_expect(initial.size() == 3 and int(initial["stage"]) == 1, "stage snapshot taken on exit")
	_expect(Idle.new_checkpoint(T0, 0).is_empty() and Idle.new_checkpoint(T0, 41).is_empty(), "stage limited to 1..40")
	_expect(Idle.new_checkpoint(-10, 1).is_empty(), "negative clock rejected")
	var initial_before: Dictionary = initial.duplicate(true)
	var economy: Dictionary = Economy.new_state()
	var economy_before: Dictionary = economy.duplicate(true)
	var zero: Dictionary = Idle.preview(initial, T0, balance)
	_expect(bool(zero.get("ok", false)) and int(zero["rewards"]["gold"]) == 0, "zero elapsed returns zero resources")
	var one_second: Dictionary = Idle.preview(initial, T0 + 1, balance)
	_expect(bool(one_second["ok"]) and int(one_second["rewards"]["gold"]) == 0, "sub-reward interval not rounded up")
	var no_reward: Dictionary = Idle.try_claim(initial, economy, catalog, T0 + 1, balance)
	_expect(not bool(no_reward["ok"]) and no_reward["reason"] == "no_reward", "no-reward claim does not commit checkpoint")
	_expect(no_reward["checkpoint"] == initial and no_reward["economy_state"] == economy, "zero claim no wallet/event modification")

	var half: Dictionary = Idle.preview(initial, T0 + 1800, balance)
	_expect(int(half["rewards"]["xp_crystals"]) == 96 and int(half["rewards"]["gold"]) == 80, "half hour stage one computed by floor")
	var hour: Dictionary = Idle.preview(initial, T0 + 3600, balance)
	_expect(int(hour["rewards"]["xp_crystals"]) == 192 and int(hour["rewards"]["gold"]) == 160, "one hour at stage one 80% yields")
	_expect(int(hour["credited_seconds"]) == 3600 and int(hour["elapsed_seconds"]) == 3600, "uncapped seconds precise")
	var eight: Dictionary = Idle.preview(initial, T0 + 28800, balance)
	_expect(int(eight["rewards"]["xp_crystals"]) == 1536 and int(eight["rewards"]["gold"]) == 1280, "eight-hour cap fixed baseline")
	var nine: Dictionary = Idle.preview(initial, T0 + 32400, balance)
	_expect(nine["rewards"] == eight["rewards"] and int(nine["credited_seconds"]) == 28800 and int(nine["elapsed_seconds"]) == 32400, "nine hours capped at eight")
	var two_days: Dictionary = Idle.preview(initial, T0 + 172800, balance)
	_expect(two_days["rewards"] == eight["rewards"], "two days do not earn more than eight hours")
	var sixty: Dictionary = Idle.preview(initial, T0 + 60, balance)
	_expect(int(sixty["rewards"]["xp_crystals"]) == 3 and int(sixty["rewards"]["gold"]) == 2, "tiny interval accumulates integer floor")
	var stage2: Dictionary = Idle.preview(Idle.new_checkpoint(T0, 2), T0 + 3600, balance)
	_expect(int(stage2["rewards"]["xp_crystals"]) == 214 and int(stage2["rewards"]["gold"]) == 179, "stage two yield floors hourly first")
	var endgame: Dictionary = Idle.preview(Idle.new_checkpoint(T0, 40), T0 + 3600, balance)
	_expect(int(endgame["rewards"]["gold"]) > int(hour["rewards"]["gold"]), "stage 40 has greater yield")

	var bad_config: Dictionary = balance.duplicate(true)
	bad_config["maximum_idle_hours"] = 24
	_expect(not bool(Idle.preview(initial, T0 + 3600, bad_config)["ok"]), "cannot remove fixed eight-hour cap via config")
	bad_config = balance.duplicate(true)
	bad_config["offline_efficiency"] = 1.5
	_expect(not bool(Idle.preview(initial, T0 + 3600, bad_config)["ok"]), "invalid efficiency rejected")
	var rollback: Dictionary = Idle.preview(initial, T0 - 10, balance)
	_expect(not bool(rollback["ok"]) and rollback["reason"] == "clock_rollback", "clock rollback not rewarded")
	_expect(not bool(Idle.try_claim(initial, economy, catalog, T0 - 10, balance)["ok"]), "clock rollback claim fails")
	_expect(not bool(Idle.preview(initial, 5000000000, balance)["ok"]), "unrealistic/invalid timestamps rejected")

	var claimed: Dictionary = Idle.try_claim(initial, economy, catalog, T0 + 3600, balance)
	_expect(bool(claimed.get("ok", false)), "one-hour offline claim succeeds")
	var next_economy: Dictionary = claimed["economy_state"]
	var next_checkpoint: Dictionary = claimed["checkpoint"]
	_expect(int(next_economy["wallet"]["gold"]) == 160 and int(next_economy["wallet"]["xp_crystals"]) == 192, "M3-3 currency payout")
	_expect(next_economy["seen_events"].has("offline:1700000000"), "stable receipt ID derived from exit checkpoint")
	_expect(int(next_checkpoint["last_exit_unix"]) == T0 + 3600, "checkpoint advanced only when reward paid")
	_expect(initial == initial_before and economy == economy_before, "successful claim does not mutate inputs")
	_expect(int(next_checkpoint["stage"]) == 1, "claim never changes the saved stage")

	var replay: Dictionary = Idle.try_claim(initial, next_economy, catalog, T0 + 7200, balance)
	_expect(not bool(replay["ok"]) and replay["reason"] == "duplicate_event", "stale checkpoint cannot re-claim with later now")
	_expect(replay["economy_state"] == next_economy, "duplicate does not grant again")
	var immediately: Dictionary = Idle.try_claim(next_checkpoint, next_economy, catalog, T0 + 3600, balance)
	_expect(not bool(immediately["ok"]) and immediately["reason"] == "no_reward", "immediate repeated poll no payout")
	var new_session: Dictionary = Idle.try_claim(next_checkpoint, next_economy, catalog, T0 + 7200, balance)
	_expect(bool(new_session["ok"]) and int(new_session["economy_state"]["wallet"]["gold"]) == 320, "fresh interval earns after checkpoint advance")
	_expect(new_session["economy_state"]["seen_events"].size() == 2, "each successful interval gets distinct receipt")
	var replay_new: Dictionary = Idle.try_claim(next_checkpoint, new_session["economy_state"], catalog, T0 + 10800, balance)
	_expect(not bool(replay_new["ok"]), "second interval replay rejected")

	var broken_wallet: Dictionary = Economy.new_state()
	broken_wallet["wallet"]["gold"] = Economy.MAX_BALANCE
	var full: Dictionary = Idle.try_claim(initial, broken_wallet, catalog, T0 + 3600, balance)
	_expect(not bool(full["ok"]) and full["reason"] == "currency_overflow", "currency limit blocks claim atomically")
	_expect(full["checkpoint"] == initial and full["economy_state"] == broken_wallet, "overflow leaves checkpoint and wallet untouched")
	var blocked_receipt: Dictionary = Economy.new_state()
	blocked_receipt["seen_events"]["offline:1700000000"] = {"kind": "spend"}
	_expect(not bool(Idle.try_claim(initial, blocked_receipt, catalog, T0 + 3600, balance)["ok"]), "cannot reuse a receipt ID of another kind")

	var raw_checkpoint: Variant = JSON.parse_string(JSON.stringify(next_checkpoint))
	var raw_economy: Variant = JSON.parse_string(JSON.stringify(next_economy))
	_expect(typeof(raw_checkpoint) == TYPE_DICTIONARY and typeof(raw_economy) == TYPE_DICTIONARY, "JSON serializable checkpoint and currency state")
	if typeof(raw_checkpoint) == TYPE_DICTIONARY and typeof(raw_economy) == TYPE_DICTIONARY:
		var restored: Dictionary = Idle.normalize_checkpoint(raw_checkpoint)
		var restored_economy: Dictionary = Economy.normalize_state(raw_economy, catalog)
		_expect(not restored.is_empty() and typeof(restored["last_exit_unix"]) == TYPE_INT, "JSON float checkpoint normalized")
		var after_reload: Dictionary = Idle.try_claim(restored, restored_economy, catalog, T0 + 7200, balance)
		_expect(bool(after_reload["ok"]) and int(after_reload["economy_state"]["wallet"]["gold"]) == 320, "new interval works after JSON roundtrip")
		_expect(not bool(Idle.try_claim(initial, restored_economy, catalog, T0 + 7200, balance)["ok"]), "old receipt still protected after JSON roundtrip")

	var corrupt: Dictionary = initial.duplicate(true)
	corrupt["last_exit_unix"] = -1
	_expect(Idle.normalize_checkpoint(corrupt).is_empty(), "invalid checkpoint epoch rejected")
	corrupt = initial.duplicate(true)
	corrupt["stage"] = 2.5
	_expect(Idle.normalize_checkpoint(corrupt).is_empty(), "fractional stage rejected")
	corrupt = initial.duplicate(true)
	corrupt["unexpected"] = 1
	_expect(Idle.normalize_checkpoint(corrupt).is_empty(), "unexpected checkpoint fields rejected")
	_finish()

func _expect(condition: bool, title: String) -> void:
	if not condition:
		failures.append(title)

func _finish() -> void:
	if failures.is_empty():
		print("M3-4 IDLE PASS: fixed 8h/80%, stage yields, rollback guards, idempotent payouts and JSON restore")
		quit(0)
		return
	for title in failures:
		push_error("M3-4 FAIL: " + title)
	quit(1)
