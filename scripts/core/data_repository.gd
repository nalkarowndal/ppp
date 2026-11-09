extends RefCounted
## Read-only static content loader. Runtime state must be stored separately.

static func load_array(path: String) -> Array:
	if not FileAccess.file_exists(path):
		push_error("Data missing: " + path)
		return []
	var content: String = FileAccess.get_file_as_string(path)
	var parser := JSON.new()
	if parser.parse(content) != OK:
		push_error("Invalid JSON in %s at line %d: %s" % [path, parser.get_error_line(), parser.get_error_message()])
		return []
	if typeof(parser.data) != TYPE_ARRAY:
		push_error("Expected JSON array: " + path)
		return []
	return parser.data

static func load_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Data missing: " + path)
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		push_error("Invalid object JSON: " + path)
		return {}
	return parser.data
