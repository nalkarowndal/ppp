extends RefCounted
## M3-4 deterministic idle/offline earnings as pure calculations + M3-3 receipt.
## The caller must snapshot the last *actual* logout timestamp and authorized
## highest-cleared stage. Call try_claim only upon app/session resume.
## M3-5 must durably commit checkpoint and economy state together.
const Economy = preload("res://scripts/core/economy_inventory.gd")

const SCHEMA_VERSION: int = 1
const MAX_STAGE: int = 40
const MAX_IDLE_SECONDS: int = 28800
const EFFICIENCY: float = 0.8
const MAX_UNIX: int = 4102444800

## Called by trusted gameplay code on exit/background, not once per timer tick.
static func new_checkpoint(exit_unix: Variant, highest_cleared_stage: Variant) -> Dictionary:
	if not _whole(exit_unix, 1, MAX_UNIX) or not _whole(highest_cleared_stage, 1, MAX_STAGE):
		return {}
	return {
		"schema_version": SCHEMA_VERSION,
		"last_exit_unix": int(exit_unix),
		"stage": int(highest_cleared_stage)
	}

## JSON parses integer-like numbers as floats. Normalize before computing.
static func normalize_checkpoint(raw: Dictionary) -> Dictionary:
	if raw.size() != 3:
		return {}
	if not _whole(raw.get("schema_version", null), SCHEMA_VERSION, SCHEMA_VERSION):
		return {}
	if not _whole(raw.get("last_exit_unix", null), 1, MAX_UNIX):
		return {}
	if not _whole(raw.get("stage", null), 1, MAX_STAGE):
		return {}
	return new_checkpoint(raw["last_exit_unix"], raw["stage"])

## Pure preview: no payout or time checkpoint changes. Clamp once.
static func preview(checkpoint: Dictionary, now_unix: Variant, balance: Dictionary) -> Dictionary:
	var cp: Dictionary = normalize_checkpoint(checkpoint)
	if cp.is_empty() or not _valid_balance(balance):
		return _preview_result(false, "invalid_state", 0, 0, {})
	if not _whole(now_unix, 1, MAX_UNIX):
		return _preview_result(false, "invalid_time", 0, 0, {})
	var elapsed_seconds: int = int(now_unix) - int(cp["last_exit_unix"])
	if elapsed_seconds < 0:
		return _preview_result(false, "clock_rollback", 0, 0, {})
	var credited_seconds: int = mini(elapsed_seconds, MAX_IDLE_SECONDS)
	var stage: int = int(cp["stage"])
	var stage_scale: float = pow(1.12, float(stage - 1))
	var xp_hourly: int = int(floor(240.0 * stage_scale))
	var gold_hourly: int = int(floor(200.0 * stage_scale))
	var credited_hours: float = float(credited_seconds) / 3600.0
	var rewards: Dictionary = {
		"xp_crystals": int(floor(credited_hours * float(xp_hourly) * EFFICIENCY)),
		"gold": int(floor(credited_hours * float(gold_hourly) * EFFICIENCY))
	}
	return _preview_result(true, "ok", elapsed_seconds, credited_seconds, rewards)

## Replay identity depends only on the saved start checkpoint, never on now.
static func try_claim(checkpoint: Dictionary, economy_state: Dictionary, catalog: Dictionary, now_unix: Variant, balance: Dictionary) -> Dictionary:
	var computed: Dictionary = preview(checkpoint, now_unix, balance)
	if not bool(computed["ok"]):
		return _claim_result(false, str(computed["reason"]), checkpoint, economy_state, {}, 0, 0, "")
	var rewards: Dictionary = computed["rewards"]
	if int(rewards["gold"]) <= 0 and int(rewards["xp_crystals"]) <= 0:
		return _claim_result(false, "no_reward", checkpoint, economy_state, rewards, int(computed["elapsed_seconds"]), int(computed["credited_seconds"]), "")
	var cp: Dictionary = normalize_checkpoint(checkpoint)
	var event_id: String = "offline:%d" % int(cp["last_exit_unix"])
	var paid: Dictionary = Economy.try_claim(economy_state, catalog, event_id, rewards, [])
	if not bool(paid.get("ok", false)):
		return _claim_result(false, str(paid.get("reason", "invalid_claim")), checkpoint, economy_state, rewards, int(computed["elapsed_seconds"]), int(computed["credited_seconds"]), event_id)
	var next_cp: Dictionary = cp.duplicate(true)
	next_cp["last_exit_unix"] = int(now_unix)
	return _claim_result(true, "ok", next_cp, paid["state"], rewards, int(computed["elapsed_seconds"]), int(computed["credited_seconds"]), event_id)

## Lock to agreed M3 values: balance policy changes require design review.
static func _valid_balance(balance: Dictionary) -> bool:
	if not _whole(balance.get("maximum_idle_hours", null), 8, 8):
		return false
	var value: Variant = balance.get("offline_efficiency", null)
	if not typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		return false
	return is_finite(float(value)) and is_equal_approx(float(value), EFFICIENCY)

static func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	if not typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		return false
	var number: float = float(value)
	return is_finite(number) and number >= float(minimum) and number <= float(maximum) and number == floor(number)

static func _preview_result(ok: bool, reason: String, elapsed_seconds: int, credited_seconds: int, rewards: Dictionary) -> Dictionary:
	return {
		"ok": ok,
		"reason": reason,
		"elapsed_seconds": elapsed_seconds,
		"credited_seconds": credited_seconds,
		"rewards": rewards.duplicate(true)
	}

static func _claim_result(ok: bool, reason: String, checkpoint: Dictionary, economy_state: Dictionary, rewards: Dictionary, elapsed_seconds: int, credited_seconds: int, event_id: String) -> Dictionary:
	return {
		"ok": ok,
		"reason": reason,
		"checkpoint": checkpoint.duplicate(true),
		"economy_state": economy_state.duplicate(true),
		"rewards": rewards.duplicate(true),
		"elapsed_seconds": elapsed_seconds,
		"credited_seconds": credited_seconds,
		"event_id": event_id
	}
