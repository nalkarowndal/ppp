extends RefCounted
## M1 DEVELOPMENT-ONLY save. Production atomic writes + backup and migrations are M3 gates.
const SAVE_PATH := "user://astral_dev_save_v1.json"

static func save_debug_state(payload: Dictionary) -> bool:
	var data: Dictionary = payload.duplicate(true)
	data["schema_version"] = 1
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Cannot open debug save: " + str(FileAccess.get_open_error()))
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	return true

static func load_debug_state() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(SAVE_PATH)) != OK:
		return {}
	if typeof(parser.data) != TYPE_DICTIONARY:
		return {}
	if int(parser.data.get("schema_version", 0)) != 1:
		return {}
	return parser.data
