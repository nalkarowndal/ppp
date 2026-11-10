extends Control
## M1 status screen and a deterministic debug battle sandbox, not production combat.
const Repo = preload("res://scripts/core/data_repository.gd")
const Sandbox = preload("res://scripts/combat/battle_sandbox.gd")
const Save = preload("res://scripts/core/save_manager.gd")
const BACKGROUND := Color("#111827")
const SURFACE := Color("#222D45")
const BORDER := Color("#526078")
const GOLD := Color("#D9BD85")
const IVORY := Color("#F5F0E5")
const MUTED := Color("#BCC6D9")

var _roster: Array = []
var _enemies: Array = []
var _sandbox = Sandbox.new()
var _status_label: Label
var _enemy_label: Label
var _party_label: Label
var _save_label: Label
var _qa_step_button: Button
var _qa_reset_button: Button
var _qa_save_button: Button
var _qa_scroll: ScrollContainer

func _ready() -> void:
	_setup_fonts()
	_roster = Repo.load_array("res://data/characters.json")
	_enemies = Repo.load_array("res://data/enemies.json")
	if _roster.size() >= 3 and not _enemies.is_empty():
		_sandbox.setup(_roster.slice(0, 3), _enemies[0])
	_build_ui()
	_refresh()
	print("M1_UI_READY: main Control scene loaded")
	if OS.has_feature("debug"):
		_qa_scroll.get_v_scroll_bar().value_changed.connect(_qa_on_scroll_changed)
		_qa_start()
	var previous := Save.load_debug_state()
	if not previous.is_empty():
		_save_label.text = "이전 개발용 저장: %d턴" % int(previous.get("sandbox_turn", 0))
	if OS.has_feature("debug"):
		print("M1_QA_RESTORED turn=%d" % int(previous.get("sandbox_turn", -1)))
		var qa_args := OS.get_cmdline_user_args()
		if qa_args.size() == 2 and qa_args[0] == "--m1-windows-qa" and qa_args[1] in ["write", "read"]:
			call_deferred("_qa_windows_run", qa_args[1])

func _setup_fonts() -> void:
	## M1 uses platform system font; portable OFL font asset is a later export gate.
	var korean_font := SystemFont.new()
	korean_font.font_names = PackedStringArray(["Noto Sans CJK KR", "Malgun Gothic", "NanumGothic", "sans-serif"])
	var ui_theme := Theme.new()
	ui_theme.default_font = korean_font
	theme = ui_theme

func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = BACKGROUND
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		safe.add_theme_constant_override("margin_" + side, 16)
	add_child(safe)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	safe.add_child(root)

	var header := _section(root)
	_text(header, "ASTRAL CHRONICLE", 24, GOLD)
	_text(header, "M1 기반 개발 중 · 임시 UI / 전투 디버그", 12, MUTED)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_qa_scroll = scroll
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)

	var arena := _section(content)
	_text(arena, "전투 테스트 구역 (플레이스홀더)", 17, GOLD)
	var strip := ColorRect.new()
	strip.color = Color("#303D59")
	strip.custom_minimum_size = Vector2(0, 130)
	arena.add_child(strip)
	_enemy_label = _text(arena, "", 15, IVORY)
	_party_label = _text(arena, "", 13, MUTED)
	_status_label = _text(arena, "", 14, GOLD)

	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	content.add_child(controls)
	var action := Button.new()
	action.text = "1턴 진행 (디버그)"
	action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action.custom_minimum_size.y = 52
	action.pressed.connect(_on_step_pressed)
	controls.add_child(action)
	_qa_step_button = action
	var restart := Button.new()
	restart.text = "초기화"
	restart.custom_minimum_size = Vector2(85, 52)
	restart.pressed.connect(_on_reset_pressed)
	controls.add_child(restart)
	_qa_reset_button = restart

	var save_section := _section(content)
	_text(save_section, "개발용 저장 확인", 16, GOLD)
	_save_label = _text(save_section, "저장 기록 없음", 12, MUTED)
	var save_button := Button.new()
	save_button.text = "샌드박스 턴 번호 저장"
	save_button.custom_minimum_size.y = 48
	save_button.pressed.connect(_on_save_pressed)
	save_section.add_child(save_button)
	_qa_save_button = save_button

	var units := _section(content)
	_text(units, "캐릭터 데이터 연결", 17, GOLD)
	for entry in _roster:
		if typeof(entry) == TYPE_DICTIONARY:
			var stats: Dictionary = entry.get("base_stats", {})
			_text(units, "%s · %s / %s · HP %d / ATK %d" % [str(entry.get("name", "?")), str(entry.get("role", "")), str(entry.get("element", "")), int(stats.get("hp", 0)), int(stats.get("atk", 0))], 12, MUTED)

	var footer := _section(root)
	_text(footer, "전투 · 동료 · 탐험 · 거점 · 메뉴  (추후 구현)", 12, MUTED)

func _section(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = SURFACE
	style.border_color = BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(margin)
	var vertical := VBoxContainer.new()
	vertical.add_theme_constant_override("separation", 8)
	margin.add_child(vertical)
	return vertical

func _text(parent: Node, value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _refresh() -> void:
	var state: Dictionary = _sandbox.snapshot()
	var enemy: Dictionary = state.get("enemy", {})
	_enemy_label.text = "%s · HP %d / %d" % [str(enemy.get("name", "적 없음")), int(enemy.get("hp", 0)), int(enemy.get("max_hp", 0))]
	var status := PackedStringArray()
	for hero in state.get("heroes", []):
		status.append("%s %d/%d" % [str(hero.get("name", "?")), int(hero.get("hp", 0)), int(hero.get("max_hp", 0))])
	_party_label.text = "아군: " + " | ".join(status)
	_status_label.text = "턴 %d · %s (M2 자동전투는 미구현)" % [int(state.get("turn", 0)), str(state.get("state", "준비"))]

func _on_step_pressed() -> void:
	_sandbox.step()
	_refresh()
	if OS.has_feature("debug"):
		print("M1_QA_EVENT STEP turn=%d" % int(_sandbox.snapshot().get("turn", -1)))

func _on_reset_pressed() -> void:
	if _roster.size() >= 3 and not _enemies.is_empty():
		_sandbox.setup(_roster.slice(0, 3), _enemies[0])
	_refresh()
	if OS.has_feature("debug"):
		print("M1_QA_EVENT RESET turn=%d" % int(_sandbox.snapshot().get("turn", -1)))

func _on_save_pressed() -> void:
	var current: Dictionary = _sandbox.snapshot()
	var ok := Save.save_debug_state({"sandbox_turn": int(current["turn"])})
	_save_label.text = "개발용 저장 성공" if ok else "개발용 저장 실패"
	if OS.has_feature("debug"):
		print("M1_QA_EVENT SAVE turn=%d success=%d" % [int(current.get("turn", -1)), int(ok)])

## Debug-export-only UI geometry and action evidence for real ADB screen touches.
## Uses Godot's canvas-to-physical-screen transform, not hard-coded pixel taps.
func _qa_start() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	print("M1_QA_SCREEN width=%d height=%d" % [DisplayServer.window_get_size().x, DisplayServer.window_get_size().y])
	print("M1_QA_USERDATA=%s" % OS.get_user_data_dir())
	_qa_emit_targets()

func _qa_on_scroll_changed(_value: float) -> void:
	call_deferred("_qa_emit_targets")

func _qa_emit_targets() -> void:
	if not OS.has_feature("debug") or not is_inside_tree():
		return
	_qa_target("STEP", _qa_step_button)
	_qa_target("RESET", _qa_reset_button)
	_qa_target("SAVE", _qa_save_button)

func _qa_target(action: String, button: Button) -> void:
	if button == null or _qa_scroll == null:
		return
	var local_center := button.size * 0.5
	var screen_pos := get_viewport().get_screen_transform() * button.get_global_transform_with_canvas() * local_center
	var visible := _qa_scroll.get_global_rect().has_point(button.get_global_rect().get_center())
	print("M1_QA_TARGET %s x=%d y=%d visible=%d" % [action, roundi(screen_pos.x), roundi(screen_pos.y), int(visible)])

## M1 Windows exported executable: real viewport-pointer injection through Godot,
## not a physical Windows mouse click. Interactive desktop mouse QA is a separate gate.
func _qa_windows_run(phase: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if phase == "read":
		var loaded: Dictionary = Save.load_debug_state()
		var success := int(loaded.get("schema_version", 0)) == 1 and int(loaded.get("sandbox_turn", -1)) == 1 and _save_label.text.contains("1턴")
		if success:
			print("M1_WINDOWS_EXE_QA_READ_PASS turn=1 in fresh process")
		else:
			push_error("M1_WINDOWS_EXE_QA_READ_FAIL no saved turn=1 in fresh process")
		get_tree().quit(0 if success else 1)
		return
	for action in ["STEP", "RESET", "STEP", "SAVE"]:
		var button: Button = _qa_step_button if action == "STEP" else (_qa_reset_button if action == "RESET" else _qa_save_button)
		if not _qa_scroll.get_global_rect().has_point(button.get_global_rect().get_center()):
			push_error("M1_WINDOWS_EXE_QA_FAIL: %s is not in scroll view" % action)
			get_tree().quit(1)
			return
		var point := button.get_global_transform_with_canvas() * (button.size * 0.5)
		var down := InputEventMouseButton.new()
		down.button_index = MOUSE_BUTTON_LEFT
		down.button_mask = MOUSE_BUTTON_MASK_LEFT
		down.position = point
		down.global_position = point
		down.pressed = true
		get_viewport().push_input(down, true)
		await get_tree().process_frame
		var up := InputEventMouseButton.new()
		up.button_index = MOUSE_BUTTON_LEFT
		up.button_mask = 0
		up.position = point
		up.global_position = point
		up.pressed = false
		get_viewport().push_input(up, true)
		await get_tree().process_frame
		var turn := int(_sandbox.snapshot().get("turn", -1))
		var expected := 0 if action == "RESET" else 1
		if turn != expected:
			push_error("M1_WINDOWS_EXE_QA_FAIL %s expected turn=%d got=%d" % [action, expected, turn])
			get_tree().quit(1)
			return
		if action == "SAVE":
			var saved: Dictionary = Save.load_debug_state()
			if int(saved.get("sandbox_turn", -1)) != 1 or not _save_label.text.contains("저장 성공"):
				push_error("M1_WINDOWS_EXE_QA_FAIL SAVE turn or label mismatch")
				get_tree().quit(1)
				return
		print("M1_WINDOWS_EXE_QA_POINTER_PASS %s turn=%d" % [action, turn])
	print("M1_WINDOWS_EXE_QA_WRITE_PASS saved turn=1")
	get_tree().quit(0)
