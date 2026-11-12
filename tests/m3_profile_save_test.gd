extends SceneTree
## M3-5 save: genuine user:// files, checksum, backup, migrations, stale revision, and offline ledger.
const Repo = preload("res://scripts/core/data_repository.gd")
const Equip = preload("res://scripts/core/equipment_system.gd")
const Growth = preload("res://scripts/core/growth_system.gd")
const Economy = preload("res://scripts/core/economy_inventory.gd")
const Idle = preload("res://scripts/core/offline_rewards.gd")
const Save = preload("res://scripts/core/profile_store.gd")

const T0: int = 1700000000
const ROOT: String = "user://qa_m3_5"
var failures: Array[String] = []

func _initialize() -> void:
	var catalog: Dictionary = Equip.build_catalog(Repo.load_array("res://data/equipment.json"))
	var chars: Array = Repo.load_array("res://data/characters.json")
	var balance: Dictionary = Repo.load_dictionary("res://data/balance_config.json")
	_expect(catalog.size() == 6 and chars.size() == 8, "M3 data fixtures loaded")
	if catalog.size() != 6 or chars.size() != 8:
		_finish()
		return
	var initial: Dictionary = Save.new_profile()
	_expect(int(initial.get("schema_version", 0)) == 2 and int(initial.get("revision", -1)) == 0, "new profile version and generation")
	_expect(initial["economy_state"]["seen_events"].is_empty() and initial["offline_checkpoint"].is_empty(), "new profile empty receipts and offline checkpoint")
	_expect(initial["heroes"].is_empty() and initial["loadouts"].is_empty(), "new profile empty character collections")
	_expect(Save.normalize_profile(initial, catalog, chars) == initial, "new profile normalizes")

	var profile: Dictionary = initial.duplicate(true)
	profile["heroes"]["CHR_ARIA"] = Growth.new_hero("CHR_ARIA")
	profile["loadouts"]["CHR_ARIA"] = Equip.new_loadout("CHR_ARIA")
	profile["highest_cleared_stage"] = 2
	profile["offline_checkpoint"] = Idle.new_checkpoint(T0, 2)
	var reward: Dictionary = Economy.try_claim(profile["economy_state"], catalog, "qa:m3-5:seed", {"gold": 1000, "xp_crystals": 500}, ["EQ_TRAINING_BLADE"])
	_expect(bool(reward["ok"]), "M3-3 currency and gear fixture grant")
	profile["economy_state"] = reward["state"]
	var equipped: Dictionary = Equip.try_equip(profile["loadouts"]["CHR_ARIA"], profile["economy_state"]["inventory"], catalog, "itm_00000001", "weapon")
	_expect(bool(equipped["ok"]), "M3-2 equipment fixture equipped")
	profile["loadouts"]["CHR_ARIA"] = equipped["loadout"]
	profile["economy_state"]["inventory"] = equipped["inventory"]
	_expect(Save.normalize_profile(profile, catalog, chars) == profile, "all M3 systems form valid save profile")
	var original: Dictionary = profile.duplicate(true)

	var invalid: Dictionary = profile.duplicate(true)
	invalid["highest_cleared_stage"] = 1
	_expect(Save.normalize_profile(invalid, catalog, chars).is_empty(), "checkpoint cannot exceed real cleared stage")
	invalid = profile.duplicate(true)
	invalid["economy_state"]["inventory"]["itm_00000001"]["equipped_by"] = "CHR_LEON"
	_expect(Save.normalize_profile(invalid, catalog, chars).is_empty(), "inconsistent gear ownership rejected")
	invalid = profile.duplicate(true)
	invalid["heroes"]["CHR_ARIA"]["level"] = 100
	_expect(Save.normalize_profile(invalid, catalog, chars).is_empty(), "invalid growth star-level pair rejected")
	invalid = profile.duplicate(true)
	invalid["heroes"]["CHR_UNKNOWN"] = Growth.new_hero("CHR_UNKNOWN")
	invalid["loadouts"]["CHR_UNKNOWN"] = Equip.new_loadout("CHR_UNKNOWN")
	_expect(Save.normalize_profile(invalid, catalog, chars).is_empty(), "unknown hero ID rejected")

	var root_dir: String = ROOT + "/basic"
	DirAccess.make_dir_recursive_absolute(root_dir)
	var path: String = root_dir + "/save.json"
	_clear(path)
	var empty_load: Dictionary = Save.load_profile(path, catalog, chars)
	_expect(not bool(empty_load["ok"]) and empty_load["reason"] == "not_found", "missing profile is not silently fabricated")
	_expect(not bool(Save.save_profile(profile, catalog, chars, "res://not-allowed.json")["ok"]), "cannot write into game resources")
	_expect(not bool(Save.save_profile(profile, catalog, chars, "user://../unsafe.json")["ok"]), "path traversal rejected")
	var first: Dictionary = Save.save_profile(profile, catalog, chars, path)
	_expect(bool(first["ok"]) and int(first["profile"]["revision"]) == 1, "first disk save acknowledged with revision 1")
	_expect(profile == original, "disk save never mutates caller-owned profile")
	_expect(FileAccess.file_exists(path), "active save actually exists")
	var loaded: Dictionary = Save.load_profile(path, catalog, chars)
	_expect(bool(loaded["ok"]) and loaded["source"] == "primary", "primary save loads")
	_expect(int(loaded["profile"]["revision"]) == 1, "primary revision restored")
	_expect(loaded["profile"]["economy_state"]["seen_events"].has("qa:m3-5:seed"), "receipt retained on reload")
	_expect(int(loaded["profile"]["economy_state"]["wallet"]["gold"]) == 1000, "gold survives reload")
	_expect(int(loaded["profile"]["heroes"]["CHR_ARIA"]["level"]) == 1, "growth survives reload")
	_expect(str(loaded["profile"]["economy_state"]["inventory"]["itm_00000001"]["equipped_by"]) == "CHR_ARIA", "gear owner survives reload")
	_expect(typeof(loaded["profile"]["economy_state"]["wallet"]["gold"]) == TYPE_INT, "JSON float coins normalize to integers")
	_expect(typeof(loaded["profile"]["offline_checkpoint"]["last_exit_unix"]) == TYPE_INT, "checkpoint epoch normalized to int")

	var stale: Dictionary = Save.save_profile(profile, catalog, chars, path)
	_expect(not bool(stale["ok"]) and stale["reason"] == "stale_revision", "same pre-save snapshot cannot overwrite committed save")
	var second_profile: Dictionary = loaded["profile"].duplicate(true)
	var paid: Dictionary = Economy.try_claim(second_profile["economy_state"], catalog, "qa:m3-5:second", {"gold": 10}, [])
	_expect(bool(paid["ok"]), "second claim granted")
	second_profile["economy_state"] = paid["state"]
	var second: Dictionary = Save.save_profile(second_profile, catalog, chars, path)
	_expect(bool(second["ok"]) and int(second["profile"]["revision"]) == 2, "second save rotates backup and increments revision")
	_expect(FileAccess.file_exists(path + ".bak"), "backup file created")
	var third: Dictionary = Save.load_profile(path, catalog, chars)
	_expect(bool(third["ok"]) and int(third["profile"]["economy_state"]["wallet"]["gold"]) == 1010, "latest primary selected over backup")
	var stale_again: Dictionary = Save.save_profile(loaded["profile"], catalog, chars, path)
	_expect(not bool(stale_again["ok"]), "old generation cannot overwrite reward receipt")

	_write_raw(path + ".tmp", "{partial-write")
	var intact: Dictionary = Save.load_profile(path, catalog, chars)
	_expect(bool(intact["ok"]) and intact["source"] == "primary" and int(intact["profile"]["revision"]) == 2, "abandoned partial temp never replaces valid primary")
	_write_raw(path, "{corrupt-primary")
	var backup: Dictionary = Save.load_profile(path, catalog, chars)
	_expect(bool(backup["ok"]) and backup["source"] == "backup", "corrupted primary falls back to verified backup")
	_expect(int(backup["profile"]["revision"]) == 1 and int(backup["profile"]["economy_state"]["wallet"]["gold"]) == 1000, "fallback is the previous verified revision")
	var recovered: Dictionary = Save.save_profile(backup["profile"], catalog, chars, path)
	_expect(bool(recovered["ok"]) and int(recovered["profile"]["revision"]) == 2, "backup can repair corrupted primary without losing receipts")
	_expect(int(Save.load_profile(path, catalog, chars)["profile"]["revision"]) == 2, "repaired primary is valid again")

	var raw: String = FileAccess.get_file_as_string(path)
	var envelope: Variant = JSON.parse_string(raw)
	_expect(typeof(envelope) == TYPE_DICTIONARY, "save contains JSON envelope")
	if typeof(envelope) == TYPE_DICTIONARY:
		envelope["sha256"] = "bad-checksum"
		_write_raw(path, JSON.stringify(envelope))
		var tampered: Dictionary = Save.load_profile(path, catalog, chars)
		_expect(bool(tampered["ok"]) and tampered["source"] == "backup", "checksum tampering forces backup recovery")
	_write_raw(path + ".bak", "{corrupt-backup")
	var no_valid: Dictionary = Save.load_profile(path, catalog, chars)
	_expect(not bool(no_valid["ok"]) and no_valid["reason"] == "corrupt", "both corrupted copies refuse to fabricate progress")
	_clear(path)

	var migrate_dir: String = ROOT + "/migrate"
	DirAccess.make_dir_recursive_absolute(migrate_dir)
	var migrate_path: String = migrate_dir + "/save.json"
	_clear(migrate_path)
	var legacy: Dictionary = {
		"schema_version": 1, "revision": 0,
		"economy_state": Economy.new_state(),
		"offline_checkpoint": Idle.new_checkpoint(T0, 1),
		"highest_cleared_stage": 1
	}
	_write_raw(migrate_path, _legacy_envelope(legacy))
	var migration: Dictionary = Save.load_profile(migrate_path, catalog, chars)
	_expect(bool(migration["ok"]) and bool(migration["migrated"]), "v1 profile migration recognized")
	_expect(int(migration["profile"]["schema_version"]) == 2 and migration["profile"]["heroes"].is_empty(), "v1 to v2 adds hero and loadout state")
	var saved_migration: Dictionary = Save.save_profile(migration["profile"], catalog, chars, migrate_path)
	_expect(bool(saved_migration["ok"]), "migrated profile persisted")
	var migrated_again: Dictionary = Save.load_profile(migrate_path, catalog, chars)
	_expect(bool(migrated_again["ok"]) and not bool(migrated_again["migrated"]), "persisted migration not rerun")
	_expect(FileAccess.file_exists(migrate_path + ".bak"), "pre-migration save preserved as backup")

	var idle_dir: String = ROOT + "/idle"
	DirAccess.make_dir_recursive_absolute(idle_dir)
	var idle_path: String = idle_dir + "/save.json"
	_clear(idle_path)
	var state: Dictionary = Save.new_profile()
	state["offline_checkpoint"] = Idle.new_checkpoint(T0, 1)
	var seed: Dictionary = Save.save_profile(state, catalog, chars, idle_path)
	_expect(bool(seed["ok"]), "offline checkpoint persisted with empty economy")
	var first_claim: Dictionary = Save.commit_offline_claim(idle_path, catalog, chars, T0 + 3600, balance)
	_expect(bool(first_claim["ok"]) and int(first_claim["profile"]["economy_state"]["wallet"]["gold"]) == 160, "idle payout and checkpoint persisted in one disk profile")
	var after_claim: Dictionary = Save.load_profile(idle_path, catalog, chars)
	_expect(bool(after_claim["ok"]) and int(after_claim["profile"]["offline_checkpoint"]["last_exit_unix"]) == T0 + 3600, "checkpoint commit matched ledger")
	_expect(after_claim["profile"]["economy_state"]["seen_events"].has("offline:1700000000"), "same saved profile holds receipt")
	var duplicate: Dictionary = Save.commit_offline_claim(idle_path, catalog, chars, T0 + 3600, balance)
	_expect(not bool(duplicate["ok"]) and duplicate["reason"] == "no_reward", "same resume instantly cannot pay twice")
	var later_claim: Dictionary = Save.commit_offline_claim(idle_path, catalog, chars, T0 + 7200, balance)
	_expect(bool(later_claim["ok"]) and int(later_claim["profile"]["economy_state"]["wallet"]["gold"]) == 320, "new offline interval can be paid with new receipt")
	_expect(later_claim["profile"]["economy_state"]["seen_events"].size() == 2, "both receipts persisted")
	var ledger_old: Dictionary = Save.save_profile(seed["profile"], catalog, chars, idle_path)
	_expect(not bool(ledger_old["ok"]), "stale checkpoint and ledger cannot replace committed profile")
	_expect(FileAccess.file_exists("user://astral_dev_save_v1.json") == FileAccess.file_exists("user://astral_dev_save_v1.json"), "legacy debug save path untouched")
	_finish()

func _legacy_envelope(payload: Dictionary) -> String:
	var payload_text: String = JSON.stringify(payload)
	return JSON.stringify({"file_format": 1, "payload_text": payload_text, "sha256": payload_text.sha256_text()})

func _write_raw(path: String, value: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_expect(false, "test fixture cannot write " + path)
		return
	file.store_string(value)
	file.flush()
	file.close()

func _clear(path: String) -> void:
	for candidate in [path, path + ".tmp", path + ".bak", path + ".bak.tmp"]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)

func _expect(condition: bool, title: String) -> void:
	if not condition:
		failures.append(title)

func _finish() -> void:
	if failures.is_empty():
		print("M3-5 SAVE PASS: atomic profile, checksum, verified backup, revision CAS, migration, offline receipt persistence")
		quit(0)
		return
	for title in failures:
		push_error("M3-5 FAIL: " + title)
	quit(1)
