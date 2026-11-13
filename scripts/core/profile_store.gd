extends RefCounted
## M3-5 production-profile prototype. Separate from M1 save_manager.gd.
## Write verified user:// temporary envelope; keep a verified previous backup;
## promote temp by rename and verify. Filesystem guarantees depend on platform.
const Repo = preload("res://scripts/core/data_repository.gd")
const Economy = preload("res://scripts/core/economy_inventory.gd")
const Growth = preload("res://scripts/core/growth_system.gd")
const Equipment = preload("res://scripts/core/equipment_system.gd")
const Idle = preload("res://scripts/core/offline_rewards.gd")

const SCHEMA_VERSION: int = 2
const FILE_FORMAT: int = 1
const MAX_PROFILE_BYTES: int = 2000000
const MAX_REVISION: int = 2000000000
const SAVE_PATH: String = "user://astral_profile_v2.json"

static func new_profile() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"revision": 0,
		"economy_state": Economy.new_state(),
		"offline_checkpoint": {},
		"heroes": {},
		"loadouts": {},
		"highest_cleared_stage": 1
	}

## Validate every saved subsystem as one coherent state. Godot JSON parser
## converts numerical fields to floats; normalize them before calling M3 APIs.
## Legacy M3 profile schema v1 (not M1's separate DEBUG SAVE) may omit
## hero/loadout collections. Preserve original economy receipts and checkpoint.
static func normalize_profile(raw: Dictionary, catalog: Dictionary, characters: Array) -> Dictionary:
	var source: Dictionary = raw
	if _whole(raw.get("schema_version", null), 1, 1):
		if raw.size() != 5:
			return {}
		source = {
			"schema_version": SCHEMA_VERSION,
			"revision": raw.get("revision", null),
			"economy_state": raw.get("economy_state", null),
			"offline_checkpoint": raw.get("offline_checkpoint", null),
			"heroes": {},
			"loadouts": {},
			"highest_cleared_stage": raw.get("highest_cleared_stage", null)
		}
	if source.size() != 7 or not _whole(source.get("schema_version", null), 2, 2):
		return {}
	if not _whole(source.get("revision", null), 0, MAX_REVISION):
		return {}
	if not _whole(source.get("highest_cleared_stage", null), 1, Idle.MAX_STAGE):
		return {}
	var original_economy: Variant = source.get("economy_state", null)
	var original_idle: Variant = source.get("offline_checkpoint", null)
	var original_heroes: Variant = source.get("heroes", null)
	var original_loadouts: Variant = source.get("loadouts", null)
	if typeof(original_economy) != TYPE_DICTIONARY or typeof(original_idle) != TYPE_DICTIONARY or typeof(original_heroes) != TYPE_DICTIONARY or typeof(original_loadouts) != TYPE_DICTIONARY:
		return {}
	var economy: Dictionary = Economy.normalize_state(original_economy, catalog)
	if economy.is_empty():
		return {}
	var idle: Dictionary = {}
	var cp: Dictionary = original_idle
	if not cp.is_empty():
		idle = Idle.normalize_checkpoint(cp)
		if idle.is_empty() or int(idle["stage"]) > int(source["highest_cleared_stage"]):
			return {}

	var known: Dictionary = {}
	for raw_character in characters:
		if typeof(raw_character) != TYPE_DICTIONARY:
			return {}
		var character: Dictionary = raw_character
		var id: String = str(character.get("id", ""))
		if id.is_empty() or known.has(id):
			return {}
		known[id] = character
	if known.size() != 8:
		return {}

	var heroes: Dictionary = original_heroes
	var loadouts: Dictionary = original_loadouts
	if heroes.size() > 8 or heroes.size() != loadouts.size():
		return {}
	var restored_heroes: Dictionary = {}
	var restored_loadouts: Dictionary = {}
	for hero_id in heroes:
		if typeof(hero_id) != TYPE_STRING or not known.has(str(hero_id)) or typeof(heroes[hero_id]) != TYPE_DICTIONARY:
			return {}
		var hero: Dictionary = heroes[hero_id].duplicate(true)
		if typeof(hero.get("id", null)) != TYPE_STRING or str(hero["id"]) != str(hero_id):
			return {}
		if not _whole(hero.get("level", null), 1, Growth.MAX_LEVEL) or not _whole(hero.get("stars", null), 1, Growth.MAX_STARS):
			return {}
		hero["level"] = int(hero["level"])
		hero["stars"] = int(hero["stars"])
		if Growth.stats_for(hero, known[hero_id]).is_empty():
			return {}
		restored_heroes[hero_id] = hero

	var inventory: Dictionary = economy["inventory"]
	var used: Dictionary = {}
	for hero_id in restored_heroes:
		if not loadouts.has(hero_id) or typeof(loadouts[hero_id]) != TYPE_DICTIONARY:
			return {}
		var ld: Dictionary = loadouts[hero_id]
		if ld.size() != 5 or typeof(ld.get("hero_id", null)) != TYPE_STRING or str(ld["hero_id"]) != str(hero_id):
			return {}
		var restored_ld: Dictionary = {"hero_id": str(hero_id)}
		for slot in Equipment.SLOTS:
			if typeof(ld.get(slot, null)) != TYPE_STRING:
				return {}
			var uid: String = str(ld[slot])
			if not uid.is_empty():
				if used.has(uid) or not inventory.has(uid):
					return {}
				var item: Dictionary = inventory[uid]
				if str(item["equipped_by"]) != str(hero_id) or str(item["equipped_slot"]) != str(slot):
					return {}
				used[uid] = true
			restored_ld[slot] = uid
		restored_loadouts[hero_id] = restored_ld
	for uid in inventory:
		if str(inventory[uid]["equipped_by"]) != "" and not used.has(uid):
			return {}
	return {
		"schema_version": SCHEMA_VERSION,
		"revision": int(source["revision"]),
		"economy_state": economy,
		"offline_checkpoint": idle,
		"heroes": restored_heroes,
		"loadouts": restored_loadouts,
		"highest_cleared_stage": int(source["highest_cleared_stage"])
	}

## Disk read always tries committed primary first, then the last verified backup.
## A valid temp is a recovery candidate only when neither committed copy exists.
static func load_profile(path: String, catalog: Dictionary, characters: Array) -> Dictionary:
	if not _safe_path(path):
		return _load_result(false, "invalid_path", "", {}, false)
	var primary: Dictionary = _read_candidate(path, catalog, characters)
	if bool(primary.get("ok", false)):
		return _load_result(true, "ok", "primary", primary["profile"], bool(primary["migrated"]))
	var backup: Dictionary = _read_candidate(path + ".bak", catalog, characters)
	if bool(backup.get("ok", false)):
		return _load_result(true, "ok", "backup", backup["profile"], bool(backup["migrated"]))
	var pending: Dictionary = _read_candidate(path + ".tmp", catalog, characters)
	if bool(pending.get("ok", false)) and not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak"):
		return _load_result(true, "ok", "tmp", pending["profile"], bool(pending["migrated"]))
	if FileAccess.file_exists(path) or FileAccess.file_exists(path + ".bak") or FileAccess.file_exists(path + ".tmp"):
		return _load_result(false, "corrupt", "", {}, false)
	return _load_result(false, "not_found", "", {}, false)

## Compare-and-swap on profile revision prevents stale snapshots from
## overwriting newly committed receipt/checkpoint states.
static func save_profile(profile: Dictionary, catalog: Dictionary, characters: Array, path: String = SAVE_PATH) -> Dictionary:
	if not _safe_path(path):
		return _save_result(false, "invalid_path", profile)
	var normalized: Dictionary = normalize_profile(profile, catalog, characters)
	if normalized.is_empty():
		return _save_result(false, "invalid_state", profile)
	var before: Dictionary = load_profile(path, catalog, characters)
	if bool(before["ok"]):
		if int(before["profile"]["revision"]) != int(normalized["revision"]):
			return _save_result(false, "stale_revision", profile)
	elif str(before["reason"]) != "not_found":
		return _save_result(false, "corrupt_on_disk", profile)
	if int(normalized["revision"]) >= MAX_REVISION:
		return _save_result(false, "revision_exhausted", profile)
	var next: Dictionary = normalized.duplicate(true)
	next["revision"] = int(normalized["revision"]) + 1
	var envelope: String = _encode(next)
	if envelope.is_empty():
		return _save_result(false, "too_large", profile)
	var directory: String = path.get_base_dir()
	if not directory in ["user://", "user:/"]:
		if DirAccess.make_dir_recursive_absolute(directory) != OK:
			return _save_result(false, "directory_error", profile)
	var temp: String = path + ".tmp"
	var backup: String = path + ".bak"
	var staged_backup: String = path + ".bak.tmp"
	if not _write_text(temp, envelope):
		return _save_result(false, "temp_write_error", profile)
	var verified: Dictionary = _read_candidate(temp, catalog, characters)
	if not bool(verified.get("ok", false)) or verified["profile"] != next:
		return _save_result(false, "temp_verification_error", profile)

	# Do not rotate a corrupt primary over a good backup. Every backup must
	# itself be verified before promotion.
	var prior_primary: Dictionary = _read_candidate(path, catalog, characters)
	if bool(prior_primary.get("ok", false)):
		if DirAccess.copy_absolute(path, staged_backup) != OK:
			return _save_result(false, "backup_copy_error", profile)
		var backup_check: Dictionary = _read_candidate(staged_backup, catalog, characters)
		if not bool(backup_check.get("ok", false)):
			return _save_result(false, "backup_verification_error", profile)
		if DirAccess.rename_absolute(staged_backup, backup) != OK:
			return _save_result(false, "backup_rename_error", profile)
	if DirAccess.rename_absolute(temp, path) != OK:
		return _save_result(false, "commit_rename_error", profile)
	var committed: Dictionary = _read_candidate(path, catalog, characters)
	if not bool(committed.get("ok", false)) or committed["profile"] != next:
		return _save_result(false, "post_commit_verification_error", profile)
	return _save_result(true, "ok", next)

## A successful offline payout and its advanced checkpoint are serialized
## into the same profile envelope. Call only on actual app resume.
static func commit_offline_claim(path: String, catalog: Dictionary, characters: Array, now_unix: Variant, balance: Dictionary) -> Dictionary:
	var loaded: Dictionary = load_profile(path, catalog, characters)
	if not bool(loaded["ok"]):
		return _save_result(false, str(loaded["reason"]), {})
	var profile: Dictionary = loaded["profile"]
	if profile["offline_checkpoint"].is_empty():
		return _save_result(false, "no_checkpoint", profile)
	if int(profile["offline_checkpoint"]["schema_version"]) == Idle.SCHEMA_VERSION:
		return _save_result(false, "awaiting_resume", profile)
	var result: Dictionary = Idle.try_claim(profile["offline_checkpoint"], profile["economy_state"], catalog, now_unix, balance)
	if not bool(result.get("ok", false)):
		return _save_result(false, str(result.get("reason", "invalid_claim")), profile)
	var updated: Dictionary = profile.duplicate(true)
	updated["economy_state"] = result["economy_state"]
	updated["offline_checkpoint"] = {}
	return save_profile(updated, catalog, characters, path)

## Load the latest profile so lifecycle writes preserve M4 stage transactions.
static func commit_idle_transition(path: String, catalog: Dictionary, characters: Array, epoch: Variant, background: bool) -> Dictionary:
	var loaded: Dictionary = load_profile(path, catalog, characters)
	if not bool(loaded["ok"]):
		return _save_result(false, str(loaded["reason"]), {})
	var profile: Dictionary = loaded["profile"]
	var pending: Dictionary = profile["offline_checkpoint"]
	# V1 used the claim time as a new anchor. After a prior claim the
	# legacy save cannot prove that a subsequent real pause occurred.
	if not background and int(pending.get("schema_version", 0)) == Idle.SCHEMA_VERSION:
		for event_id in profile["economy_state"]["seen_events"]:
			if str(event_id).begins_with("offline:"):
				profile["offline_checkpoint"] = {}
				return save_profile(profile, catalog, characters, path)
	var checkpoint: Dictionary
	if background:
		checkpoint = Idle.begin_background(pending, epoch, int(profile["highest_cleared_stage"]), int(profile["revision"]) + 1)
	else:
		checkpoint = Idle.finish_background(pending, epoch)
	if checkpoint.is_empty():
		return _save_result(true, "unchanged_checkpoint", profile)
	profile["offline_checkpoint"] = checkpoint
	return save_profile(profile, catalog, characters, path)

static func _encode(payload: Dictionary) -> String:
	var payload_text: String = JSON.stringify(payload)
	if payload_text.to_utf8_buffer().size() > MAX_PROFILE_BYTES / 2:
		return ""
	var envelope: String = JSON.stringify({
		"file_format": FILE_FORMAT,
		"payload_text": payload_text,
		"sha256": payload_text.sha256_text()
	})
	if envelope.to_utf8_buffer().size() > MAX_PROFILE_BYTES:
		return ""
	return envelope

static func _read_candidate(path: String, catalog: Dictionary, characters: Array) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false}
	var bytes: int = int(file.get_length())
	if bytes <= 0 or bytes > MAX_PROFILE_BYTES:
		file.close()
		return {"ok": false}
	var content: String = file.get_as_text()
	file.close()
	var file_parser: JSON = JSON.new()
	if file_parser.parse(content) != OK or typeof(file_parser.data) != TYPE_DICTIONARY:
		return {"ok": false}
	var env: Dictionary = file_parser.data
	if env.size() != 3 or not _whole(env.get("file_format", null), 1, 1):
		return {"ok": false}
	if typeof(env.get("payload_text", null)) != TYPE_STRING or typeof(env.get("sha256", null)) != TYPE_STRING:
		return {"ok": false}
	var payload_text: String = env["payload_text"]
	if payload_text.is_empty() or payload_text.to_utf8_buffer().size() > MAX_PROFILE_BYTES / 2:
		return {"ok": false}
	if payload_text.sha256_text() != str(env["sha256"]):
		return {"ok": false}
	var payload_parser: JSON = JSON.new()
	if payload_parser.parse(payload_text) != OK or typeof(payload_parser.data) != TYPE_DICTIONARY:
		return {"ok": false}
	var inner: Dictionary = payload_parser.data
	var migrated: bool = _whole(inner.get("schema_version", null), 1, 1)
	var profile: Dictionary = normalize_profile(inner, catalog, characters)
	if profile.is_empty():
		return {"ok": false}
	return {"ok": true, "profile": profile, "migrated": migrated}

static func _write_text(path: String, content: String) -> bool:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(content)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	return error == OK

static func _whole(value: Variant, minimum: int, maximum: int) -> bool:
	if not typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		return false
	var number: float = float(value)
	return is_finite(number) and number >= float(minimum) and number <= float(maximum) and number == floor(number)

static func _safe_path(path: String) -> bool:
	return path.begins_with("user://") and path.length() > 13 and path.ends_with(".json") and not path.contains("..") and not path.contains("\\") and not path.substr(7).contains(":")

static func _save_result(ok: bool, reason: String, profile: Dictionary) -> Dictionary:
	return {"ok": ok, "reason": reason, "profile": profile.duplicate(true)}

static func _load_result(ok: bool, reason: String, source: String, profile: Dictionary, migrated: bool) -> Dictionary:
	return {"ok": ok, "reason": reason, "source": source, "profile": profile.duplicate(true), "migrated": migrated}
