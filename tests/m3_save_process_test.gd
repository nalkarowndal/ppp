extends SceneTree
## Run as independent Godot processes: -- write | -- read | -- verify.
const Repo = preload("res://scripts/core/data_repository.gd")
const Equip = preload("res://scripts/core/equipment_system.gd")
const Economy = preload("res://scripts/core/economy_inventory.gd")
const Idle = preload("res://scripts/core/offline_rewards.gd")
const Save = preload("res://scripts/core/profile_store.gd")
const T0: int = 1700000000
const PATH: String = "user://qa_m3_5_process/profile.json"

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		_fail("expected write / read / verify")
		return
	var catalog: Dictionary = Equip.build_catalog(Repo.load_array("res://data/equipment.json"))
	var chars: Array = Repo.load_array("res://data/characters.json")
	var balance: Dictionary = Repo.load_dictionary("res://data/balance_config.json")
	if args[0] == "write":
		DirAccess.make_dir_recursive_absolute("user://qa_m3_5_process")
		for path in [PATH, PATH + ".tmp", PATH + ".bak", PATH + ".bak.tmp"]:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
		var profile: Dictionary = Save.new_profile()
		profile["offline_checkpoint"] = Idle.new_checkpoint(T0, 1)
		var grant: Dictionary = Economy.try_claim(profile["economy_state"], catalog, "process:seed", {"gold": 35}, [])
		if not bool(grant["ok"]):
			_fail("could not create seed reward")
			return
		profile["economy_state"] = grant["state"]
		if not bool(Save.save_profile(profile, catalog, chars, PATH)["ok"]):
			_fail("could not persist first process")
			return
		print("M3-5 PROCESS WRITE PASS: profile persisted in a new process")
		quit(0)
	elif args[0] == "read":
		var loaded: Dictionary = Save.load_profile(PATH, catalog, chars)
		if not bool(loaded["ok"]) or int(loaded["profile"]["economy_state"]["wallet"]["gold"]) != 35:
			_fail("process reboot lost currency")
			return
		if not bool(Save.commit_idle_transition(PATH, catalog, chars, T0 + 3600, false)["ok"]):
			_fail("process reboot failed to settle offline time")
			return
		var paid: Dictionary = Save.commit_offline_claim(PATH, catalog, chars, T0 + 3600, balance)
		if not bool(paid["ok"]) or int(paid["profile"]["economy_state"]["wallet"]["gold"]) != 195:
			_fail("process reboot failed offline claim")
			return
		print("M3-5 PROCESS READ PASS: offline reward and receipt saved across processes")
		quit(0)
	elif args[0] == "verify":
		var loaded: Dictionary = Save.load_profile(PATH, catalog, chars)
		if not bool(loaded["ok"]):
			_fail("third process missing save")
			return
		var profile: Dictionary = loaded["profile"]
		if int(profile["economy_state"]["wallet"]["gold"]) != 195 or not profile["economy_state"]["seen_events"].has("offline:1700000000"):
			_fail("third process lost receipt")
			return
		var repeat: Dictionary = Save.commit_offline_claim(PATH, catalog, chars, T0 + 3600, balance)
		if bool(repeat["ok"]) or int(Save.load_profile(PATH, catalog, chars)["profile"]["economy_state"]["wallet"]["gold"]) != 195:
			_fail("third process double-granted offline reward")
			return
		print("M3-5 PROCESS VERIFY PASS: durable receipt survives actual process restart")
		quit(0)
	else:
		_fail("unexpected argument")

func _fail(message: String) -> void:
	push_error("M3-5 PROCESS FAIL: " + message)
	quit(1)
