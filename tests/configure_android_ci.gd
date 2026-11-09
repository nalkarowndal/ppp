extends SceneTree
## Use with Godot 4.7.2 --headless --editor --script res://tests/configure_android_ci.gd
## Per-runner Android SDK settings only. No signing secrets are committed.
func _initialize() -> void:
	var sdk: String = OS.get_environment("ANDROID_HOME")
	var java: String = OS.get_environment("JAVA_HOME")
	if sdk.is_empty() or java.is_empty():
		push_error("ANDROID CONFIG FAIL: ANDROID_HOME or JAVA_HOME missing")
		quit(1)
		return
	var settings: EditorSettings = EditorInterface.get_editor_settings()
	if settings == null:
		push_error("ANDROID CONFIG FAIL: editor settings unavailable")
		quit(1)
		return
	settings.set_setting("export/android/android_sdk_path", sdk)
	settings.set_setting("export/android/java_sdk_path", java)
	print("ANDROID CONFIG PASS: configured SDK locations (secrets omitted)")
	quit(0)
