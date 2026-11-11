extends Control
## M2-5 interactive Godot battle preview. Not a production art/final QA scene.
## M1 legacy debug scene remains the startup scene and keeps its QA controls.
const Repo = preload("res://scripts/core/data_repository.gd")
const Battle = preload("res://scripts/combat/auto_battle_core.gd")
const View = preload("res://scripts/ui/battle_view_model.gd")
const BG: Color = Color("#111827")
const SURFACE: Color = Color("#222D45")
const RAISED: Color = Color("#303D59")
const BORDER: Color = Color("#526078")
const GOLD: Color = Color("#D9BD85")
const IVORY: Color = Color("#F5F0E5")
const MUTED: Color = Color("#BCC6D9")
const MAGIC: Color = Color("#8BA8FF")
const GREEN: Color = Color("#7ECCAA")
const RED: Color = Color("#F08F96")
const TICKS_PER_SECOND: int = 20

var _battle = Battle.new()
var _speed: int = 1
var _auto_ultimates: bool = true
var _reduced_motion: bool = false
var _tick_accumulator: float = 0.0
var _last_event_tick: int = -1
var _last_event_index: int = 0
var _cards: Dictionary = {}
var _ally_cards: HBoxContainer
var _enemy_cards: HBoxContainer
var _battle_status: Label
var _combat_log: Label
var _auto_button: Button
var _speed_button: Button
var _motion_button: Button

func _ready() -> void:
	_set_korean_font()
	_build_layout()
	_start_battle()

func _process(delta: float) -> void:
	if str(_battle.snapshot().get("state", "")) != "running":
		return
	_tick_accumulator += minf(delta, 0.1) * float(TICKS_PER_SECOND * _speed)
	var pending: int = mini(16, int(floor(_tick_accumulator)))
	if pending > 0:
		_tick_accumulator -= float(pending)
		advance_ticks(pending)

## Public deterministic scene driver used by both _process and integration QA.
func advance_ticks(count: int) -> Dictionary:
	var updated: Dictionary = _battle.step_ticks(maxi(0, count))
	refresh_view()
	return updated

func refresh_view() -> void:
	var state: Dictionary = _battle.snapshot()
	_battle_status.text = View.battle_title(state)
	for unit in state.get("allies", []) + state.get("enemies", []):
		var id: String = str(unit.get("id", ""))
		if not _cards.has(id):
			continue
		var widgets: Dictionary = _cards[id]
		var bar: ProgressBar = widgets["bar"]
		bar.value = float(unit.get("hp", 0)) * 100.0 / float(maxi(1, int(unit.get("max_hp", 1))))
		var hp_label: Label = widgets["hp_label"]
		hp_label.text = View.hp_text(unit)
		var energy: Label = widgets["energy"]
		energy.text = "기력 %d/100" % int(unit.get("energy", 0)) if str(unit.get("team", "")) == "ally" else "적 · %s" % str(unit.get("role", ""))
		var status_label: Label = widgets["status"]
		status_label.text = View.status_text(unit, int(state["ticks"]))
		if str(unit.get("team", "")) == "ally":
			var button: Button = widgets["ultimate"]
			var queued: bool = bool(unit.get("ultimate_requested", false))
			button.text = "예약됨" if queued else ("궁극기 %d%%" % int(unit.get("energy", 0)))
			button.disabled = _auto_ultimates or queued or int(unit.get("energy", 0)) < 100 or int(unit.get("hp", 0)) <= 0 or str(state.get("state", "")) != "running"
	_combat_log.text = View.log_text(state.get("recent_events", []), state)
	_consume_new_events(state)
	_auto_button.text = "궁극기 AUTO ON" if _auto_ultimates else "궁극기 AUTO OFF"
	_speed_button.text = "속도 %d×" % _speed
	_motion_button.text = "동작 줄이기 ON" if _reduced_motion else "동작 줄이기 OFF"

func _set_korean_font() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans CJK KR", "Malgun Gothic", "NanumGothic", "sans-serif"])
	var ui_theme := Theme.new()
	ui_theme.default_font = font
	theme = ui_theme

func _build_layout() -> void:
	var background := ColorRect.new()
	background.color = BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var safe := MarginContainer.new()
	safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		safe.add_theme_constant_override("margin_" + side, 12)
	add_child(safe)
	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 9)
	safe.add_child(root_box)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	root_box.add_child(header)
	var back := _button(header, "← 돌아가기", "BackButton", 48)
	back.pressed.connect(_on_back)
	_text(header, "ASTRAL CHRONICLE", 18, GOLD).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var restart := _button(header, "재시작", "RestartButton", 48)
	restart.pressed.connect(_on_restart)

	_battle_status = _text(root_box, "전투 준비", 15, IVORY)
	_battle_status.name = "BattleStatus"
	_text(root_box, "M2-5 전투 프리뷰 · 3대3 / 적 체력 ×4 (테스트)", 12, MUTED)

	var scroll := ScrollContainer.new()
	scroll.name = "BattleScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_box.add_child(scroll)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)

	var enemy_section := _section(content)
	_text(enemy_section, "적 진영  ·  FRONT / BACK", 15, RED)
	_enemy_cards = HBoxContainer.new()
	_enemy_cards.name = "EnemyCards"
	_enemy_cards.add_theme_constant_override("separation", 5)
	enemy_section.add_child(_enemy_cards)

	var arena := _section(content)
	_text(arena, "✦  전투 진행  ✦", 15, GOLD).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text(arena, "피격 · 회복 · 궁극기 이벤트는 카드 강조로 표시", 11, MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var ally_section := _section(content)
	_text(ally_section, "아군 진영  ·  영웅 / 스킬", 15, GREEN)
	_ally_cards = HBoxContainer.new()
	_ally_cards.name = "AllyCards"
	_ally_cards.add_theme_constant_override("separation", 5)
	ally_section.add_child(_ally_cards)

	var controls := _section(content)
	var first_row := HBoxContainer.new()
	first_row.add_theme_constant_override("separation", 6)
	controls.add_child(first_row)
	_auto_button = _button(first_row, "궁극기 AUTO ON", "AutoButton", 52)
	_auto_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_auto_button.pressed.connect(_on_auto)
	_speed_button = _button(first_row, "속도 1×", "SpeedButton", 52)
	_speed_button.pressed.connect(_on_speed)
	_motion_button = _button(controls, "동작 줄이기 OFF", "ReducedMotionButton", 48)
	_motion_button.pressed.connect(_on_motion)
	_text(controls, "AUTO OFF일 때 기력 100인 영웅의 궁극기를 직접 예약할 수 있습니다.", 12, MUTED)

	var log_section := _section(content)
	_text(log_section, "전투 기록", 14, GOLD)
	_combat_log = _text(log_section, "전투 대기 중", 12, IVORY)
	_combat_log.name = "CombatLog"

	_text(root_box, "개발용 전투 미리보기 · 저장/보상/최종 아트 미연결", 11, MUTED)

func _start_battle() -> void:
	var roster: Array = Repo.load_array("res://data/characters.json")
	var enemy_data: Array = Repo.load_array("res://data/enemies.json")
	var skills: Array = Repo.load_array("res://data/skills.json")
	_battle = Battle.new()
	if not _battle.configure_skills(skills) or roster.size() < 3 or enemy_data.size() < 3:
		_battle_status.text = "전투 데이터가 부족합니다."
		return
	var party: Array = []
	var foes: Array = []
	for i in range(3):
		party.append(roster[i].duplicate(true))
		var enemy: Dictionary = enemy_data[i].duplicate(true)
		enemy["hp"] = int(enemy.get("hp", 100)) * 4  # Preview-only endurance, not JSON balance.
		foes.append(enemy)
	_battle.setup(party, foes, 20261111)
	_speed = 1
	_auto_ultimates = true
	_battle.set_auto_ultimates(true)
	_tick_accumulator = 0.0
	_last_event_tick = -1
	_last_event_index = 0
	_cards.clear()
	for holder in [_ally_cards, _enemy_cards]:
		for child in holder.get_children():
			holder.remove_child(child)
			child.queue_free()
	var state: Dictionary = _battle.snapshot()
	for enemy in state["enemies"]:
		_add_card(_enemy_cards, enemy)
	for ally in state["allies"]:
		_add_card(_ally_cards, ally)
	refresh_view()
	print("M2_5_BATTLE_READY allies=%d enemies=%d" % [state["allies"].size(), state["enemies"].size()])

func _add_card(parent: HBoxContainer, unit: Dictionary) -> void:
	var id: String = str(unit["id"])
	var hero: bool = str(unit.get("team", "")) == "ally"
	var panel := PanelContainer.new()
	panel.name = "Unit_" + id
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size = Vector2(84, 165 if hero else 118)
	var style := StyleBoxFlat.new()
	style.bg_color = RAISED
	style.border_color = MAGIC if hero else RED
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 5)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	margin.add_child(column)

	_text(column, str(unit.get("name", "?")).substr(0, 1), 22, MAGIC if hero else RED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var name: Label = _text(column, str(unit.get("name", "?")), 12, IVORY)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hp_label := _text(column, "", 11, MUTED)
	hp_label.name = "HpText"
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = 11
	bar.max_value = 100
	bar.show_percentage = false
	column.add_child(bar)
	var energy := _text(column, "", 11, MUTED)
	var status_label := _text(column, "상태 없음", 11, GOLD)
	status_label.name = "StatusText"
	status_label.custom_minimum_size.y = 29
	var ultimate: Button = null
	if hero:
		ultimate = _button(column, "궁극기 0%", "UltimateButton", 48)
		ultimate.pressed.connect(_on_ultimate.bind(id))
	_cards[id] = {"panel": panel, "bar": bar, "hp_label": hp_label, "energy": energy, "status": status_label, "ultimate": ultimate}

func _consume_new_events(state: Dictionary) -> void:
	## Ordinal starts from zero at every historical tick. Do not seed it
	## from the last cursor: the capped event buffer contains old entries.
	var newest_tick: int = _last_event_tick
	var newest_ordinal: int = _last_event_index
	var scanned_tick: int = -1
	var ordinal: int = 0
	for e in state.get("recent_events", []):
		var tick: int = int(e.get("tick", -1))
		if tick != scanned_tick:
			scanned_tick = tick
			ordinal = 0
		ordinal += 1
		if tick < _last_event_tick or (tick == _last_event_tick and ordinal <= _last_event_index):
			continue
		newest_tick = tick
		newest_ordinal = ordinal
		if _reduced_motion:
			continue
		var type: String = str(e.get("type", ""))
		var id: String = str(e.get("target_id", ""))
		var tint: Color = RED
		if type == "skill_cast":
			id = str(e.get("actor_id", ""))
			tint = GOLD
		elif type in ["heal", "shield"] or (type == "status_tick" and bool(e.get("heal", false))):
			tint = GREEN
		elif not type in ["skill_hit", "basic_attack", "status_tick"]:
			continue
		if _cards.has(id):
			var panel: PanelContainer = _cards[id]["panel"]
			## self_modulate affects the panel background, not Korean text /
			## status labels in child Controls. Keep foreground readable.
			panel.self_modulate = Color.WHITE.lerp(tint, 0.30)
			var tween := create_tween().bind_node(panel)
			tween.tween_property(panel, "self_modulate", Color.WHITE, 0.22)
	_last_event_tick = newest_tick
	_last_event_index = newest_ordinal

func _on_auto() -> void:
	_auto_ultimates = not _auto_ultimates
	_battle.set_auto_ultimates(_auto_ultimates)
	refresh_view()

func _on_speed() -> void:
	_speed = 1 if _speed == 3 else _speed + 1
	refresh_view()

func _on_motion() -> void:
	_reduced_motion = not _reduced_motion
	refresh_view()

func _on_ultimate(id: String) -> void:
	if _auto_ultimates:
		return
	if _battle.request_ultimate("ally", id):
		print("M2_5_ULT_QUEUED hero=%s" % id)
	refresh_view()

func _on_restart() -> void:
	_start_battle()

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _section(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = SURFACE
	style.border_color = BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(11)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 9)
	margin.add_theme_constant_override("margin_bottom", 9)
	panel.add_child(margin)
	var vertical := VBoxContainer.new()
	vertical.add_theme_constant_override("separation", 6)
	margin.add_child(vertical)
	return vertical

func _text(parent: Node, value: String, px: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Node, value: String, node_name: String, height: int) -> Button:
	var button := Button.new()
	button.text = value
	button.name = node_name
	button.custom_minimum_size.y = height
	button.add_theme_font_size_override("font_size", 12)
	parent.add_child(button)
	return button
