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

func _ready() -> void:
	_roster = Repo.load_array("res://data/characters.json")
	_enemies = Repo.load_array("res://data/enemies.json")
	if _roster.size() >= 3 and not _enemies.is_empty():
		_sandbox.setup(_roster.slice(0, 3), _enemies[0])
	_build_ui()
	_refresh()
	var previous := Save.load_debug_state()
	if not previous.is_empty():
		_save_label.text = "이전 개발용 저장: %d턴" % int(previous.get("sandbox_turn", 0))

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
	var restart := Button.new()
	restart.text = "초기화"
	restart.custom_minimum_size = Vector2(85, 52)
	restart.pressed.connect(_on_reset_pressed)
	controls.add_child(restart)

	var units := _section(content)
	_text(units, "캐릭터 데이터 연결", 17, GOLD)
	for entry in _roster:
		if typeof(entry) == TYPE_DICTIONARY:
			var stats: Dictionary = entry.get("base_stats", {})
			_text(units, "%s · %s / %s · HP %d / ATK %d" % [str(entry.get("name", "?")), str(entry.get("role", "")), str(entry.get("element", "")), int(stats.get("hp", 0)), int(stats.get("atk", 0))], 12, MUTED)

	var save_section := _section(content)
	_text(save_section, "개발용 저장 확인", 16, GOLD)
	_save_label = _text(save_section, "저장 기록 없음", 12, MUTED)
	var save_button := Button.new()
	save_button.text = "샌드박스 턴 번호 저장"
	save_button.custom_minimum_size.y = 48
	save_button.pressed.connect(_on_save_pressed)
	save_section.add_child(save_button)

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

func _on_reset_pressed() -> void:
	if _roster.size() >= 3 and not _enemies.is_empty():
		_sandbox.setup(_roster.slice(0, 3), _enemies[0])
	_refresh()

func _on_save_pressed() -> void:
	var current: Dictionary = _sandbox.snapshot()
	var ok := Save.save_debug_state({"sandbox_turn": int(current["turn"])})
	_save_label.text = "개발용 저장 성공" if ok else "개발용 저장 실패"
