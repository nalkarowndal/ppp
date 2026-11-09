extends SceneTree
## Two independent Godot processes: --script res://tests/save_process_test.gd -- write|read
## Only validates M1 debug save; production atomic save/migrations are M3.
const Save = preload("res://scripts/core/save_manager.gd")
const TEST_TURN := 73

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("SAVE PROCESS FAIL: expected write/read arg")
		quit(2)
		return
	match args[0]:
		"write":
			if not Save.save_debug_state({"sandbox_turn": TEST_TURN}):
				push_error("SAVE PROCESS FAIL: cannot write debug save")
				quit(1)
				return
			print("SAVE PROCESS WRITE PASS: persisted turn %d" % TEST_TURN)
			quit(0)
		"read":
			var state: Dictionary = Save.load_debug_state()
			if int(state.get("schema_version", 0)) != 1 or int(state.get("sandbox_turn", -1)) != TEST_TURN:
				push_error("SAVE PROCESS FAIL: state missing after real process restart")
				quit(1)
				return
			print("SAVE PROCESS READ PASS: recovered turn %d after fresh process" % TEST_TURN)
			quit(0)
		_:
			push_error("SAVE PROCESS FAIL: unexpected argument")
			quit(2)
