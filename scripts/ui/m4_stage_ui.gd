extends Control
## M4 portrait vertical-slice stage selector. Reuses real M2 battles and
## M3 atomically stored rewards, keeps M1/M2/M3 screens independently usable.
const Stage = preload("res://scripts/core/m4_stage_run.gd")
const Store = preload("res://scripts/core/profile_store.gd")

const BG := Color("#111827")
const PANEL := Color("#222D45")
const BORDER := Color("#526078")
const GOLD := Color("#D9BD85")
const IVORY := Color("#F5F0E5")
const MUTED := Color("#BCC6D9")
const GREEN := Color("#7ECCAA")
const RED := Color("#F08F96")
const TICK_RATE: int = 20

@export var profile_path: String = "user://astral_profile_v2.json"
var _runner = Stage.new()
var _ready_ok: bool = false
var _active: bool = false
var _speed: int = 1
var _accumulated: float = 0.0
var _safe: MarginContainer
var _status_label: Label
var _wallet_label: Label
var _ally_label: Label
var _enemy_label: Label
var _reward_label: Label
var _speed_button: Button
var _growth_button: Button
var _back_button: Button
var _stage_buttons: Dictionary = {}

func _ready() -> void:
	_set_korean_font()
	_build_ui()
	var result: Dictionary = _runner.initialize(profile_path)
	_ready_ok = bool(result.get("ok", false))
	if not _ready_ok:
		_status_label.text = "저장 데이터를 읽을 수 없습니다: " + str(result.get("reason", "unknown"))
		_reward_label.text = "저장 오류를 해결한 뒤 다시 실행해 주세요."
	else:
		_status_label.text = "스테이지를 선택하세요. 기본 편성: 아리아 / 세레나 / 레온"
		_reward_label.text = "전투에 승리하면 실제 재화와 첫 클리어 장비가 저장됩니다."
	_refresh_stages()
	_refresh_wallet()
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)

func current_stage() -> int:
	return _runner.current_stage()

## Same deterministic UI test hook used by the real frame-driven battle.
func advance_ticks(count: int) -> Dictionary:
	if not _active:
		return _runner.battle_snapshot()
	var state: Dictionary = _runner.advance_ticks(count)
	_render_battle(state)
	if str(state.get("state", "")) != "running":
		_active = false
		if str(state.get("state", "")) == "victory":
			var claim: Dictionary = _runner.settle_victory()
			if bool(claim.get("ok", false)):
				var reward: Dictionary = claim["rewards"]
				var equipment: String = " · 첫 클리어 장비 획득" if not claim["items"].is_empty() else ""
				var text_kind: String = "첫 클리어" if bool(claim["first_clear"]) else "재도전"
				_reward_label.text = "%s 보상 저장: 골드 +%d / 경험치 결정 +%d%s" % [
					text_kind, int(reward["gold"]), int(reward["xp_crystals"]), equipment
				]
				_status_label.text = "스테이지 %02d 클리어 · 저장 완료" % current_stage()
			else:
				_reward_label.text = "승리했지만 저장 실패: " + str(claim.get("reason", "unknown"))
				_status_label.text = "보상 미수령 · 새 전투를 시작하지 말고 저장을 확인하세요."
		else:
			_status_label.text = "패배 · 성장/장비 강화를 확인한 뒤 재도전하세요."
			_reward_label.text = "패배에는 보상이 지급되지 않습니다."
		_refresh_stages()
		_refresh_wallet()
	return state

func _process(delta: float) -> void:
	if not _active:
		return
	_accumulated += minf(delta, 0.1) * float(TICK_RATE * _speed)
	var steps: int = mini(16, int(floor(_accumulated)))
	if steps > 0:
		_accumulated -= float(steps)
		advance_ticks(steps)

func _on_stage_pressed(stage: int) -> void:
	if not _ready_ok or _active:
		return
	var result: Dictionary = _runner.start_stage(stage, ["CHR_ARIA", "CHR_SERENA", "CHR_LEON"])
	if not bool(result.get("ok", false)):
		_status_label.text = "스테이지 진입 실패: " + str(result.get("reason", "unknown"))
		return
	_active = true
	_accumulated = 0.0
	_reward_label.text = "전투 중 · 승리한 경우에만 보상이 영구 저장됩니다."
	_status_label.text = "스테이지 %02d · 전투 중" % stage
	_render_battle(_runner.battle_snapshot())
	_refresh_stages()

func _render_battle(state: Dictionary) -> void:
	var allies := PackedStringArray()
	var enemies := PackedStringArray()
	for unit in state.get("allies", []):
		allies.append("%s %d/%d" % [str(unit.get("name", "?")), int(unit.get("hp", 0)), int(unit.get("max_hp", 1))])
	for unit in state.get("enemies", []):
		enemies.append("%s %d/%d" % [str(unit.get("name", "?")), int(unit.get("hp", 0)), int(unit.get("max_hp", 1))])
	_ally_label.text = "아군 HP · " + "  |  ".join(allies)
	_enemy_label.text = "적 HP · " + "  |  ".join(enemies)

func _refresh_stages() -> void:
	var allowed: Dictionary = {}
	for entry in _runner.available_stages():
		var stage: int = int(entry["stage"])
		allowed[stage] = entry
	for stage in range(1, Stage.STAGE_COUNT + 1):
		var button: Button = _stage_buttons[stage]
		var info: Dictionary = allowed.get(stage, {})
		button.disabled = _active or not bool(info.get("unlocked", false))
		var marker: String = "✓ 클리어" if bool(info.get("cleared", false)) else ("도전 가능" if not button.disabled else "잠김")
		button.text = "STAGE %02d  ·  %s" % [stage, marker]

func _refresh_wallet() -> void:
	var profile: Dictionary = _runner.profile_snapshot()
	if profile.is_empty():
		_wallet_label.text = "프로필 정보를 불러올 수 없습니다."
		return
	var wallet: Dictionary = profile["economy_state"]["wallet"]
	_wallet_label.text = "골드 %d  ·  경험치 결정 %d  ·  강화석 %d" % [
		int(wallet["gold"]), int(wallet["xp_crystals"]), int(wallet["enhancement_stones"])
	]

func _set_korean_font() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Noto Sans CJK KR", "Malgun Gothic", "NanumGothic", "sans-serif"])
	var screen_theme := Theme.new()
	screen_theme.default_font = font
	theme = screen_theme

func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = BG
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	_safe = MarginContainer.new()
	_safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_safe)
	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 10)
	_safe.add_child(root_box)
	var header := HBoxContainer.new()
	root_box.add_child(header)
	_back_button = _button(header, "← 홈", "HomeButton", 52)
	_back_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/main.tscn"))
	_text(header, "ASTRAL · M4 모험", 17, GOLD).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_growth_button = _button(header, "성장/장비", "GrowthButton", 52)
	_growth_button.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/m3_progression.tscn"))
	_status_label = _text(root_box, "M4 스테이지 준비 중", 14, IVORY)
	_status_label.name = "StageStatus"
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root_box.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	scroll.add_child(body)

	var stage_section := _section(body)
	_text(stage_section, "CHAPTER 01 · 숲의 관문", 18, GOLD)
	_text(stage_section, "첫 클리어 장비 1회 지급 / 재도전 시 재화 획득", 12, MUTED)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	stage_section.add_child(grid)
	for stage in range(1, Stage.STAGE_COUNT + 1):
		var button: Button = _button(grid, "STAGE %02d" % stage, "StageButton%d" % stage, 56)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.x = 130
		button.disabled = true
		button.pressed.connect(_on_stage_pressed.bind(stage))
		_stage_buttons[stage] = button

	var fight_section := _section(body)
	_text(fight_section, "LIVE AUTO BATTLE · 20Hz", 16, GOLD)
	_ally_label = _text(fight_section, "아군 HP · 전투 대기", 12, GREEN)
	_enemy_label = _text(fight_section, "적 HP · 전투 대기", 12, RED)
	_speed_button = _button(fight_section, "전투 속도 1×", "SpeedButton", 52)
	_speed_button.pressed.connect(func() -> void:
		_speed = 1 if _speed >= 3 else _speed + 1
		_speed_button.text = "전투 속도 %d×" % _speed
	)

	var reward_section := _section(body)
	_text(reward_section, "보상 및 저장 결과", 16, GOLD)
	_reward_label = _text(reward_section, "전투를 선택해 주세요.", 13, IVORY)
	_reward_label.name = "RewardResult"

	var footer := _section(root_box)
	_wallet_label = _text(footer, "재화 확인 중", 12, GOLD)
	_text(footer, "M4 기술 수직슬라이스 · 본편 아트/실기기 승인 전", 11, MUTED)

func _section(parent: Node) -> VBoxContainer:
	var container := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(11)
	container.add_theme_stylebox_override("panel", style)
	parent.add_child(container)
	var padding := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		padding.add_theme_constant_override("margin_" + side, 10)
	container.add_child(padding)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 7)
	padding.add_child(content)
	return content

func _text(parent: Node, value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Node, value: String, node_name: String, height: int) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = value
	button.custom_minimum_size.y = height
	button.add_theme_font_size_override("font_size", 12)
	parent.add_child(button)
	return button

func _apply_safe_area() -> void:
	if _safe == null:
		return
	var left: int = 14
	var right: int = 14
	var top: int = 14
	var bottom: int = 14
	if OS.has_feature("mobile"):
		var area: Rect2i = DisplayServer.get_display_safe_area()
		var pixels: Vector2i = DisplayServer.window_get_size()
		var viewport: Vector2 = get_viewport_rect().size
		if pixels.x > 0 and pixels.y > 0 and area.size.x > 0 and area.size.y > 0:
			var sx: float = viewport.x / float(pixels.x)
			var sy: float = viewport.y / float(pixels.y)
			left = maxi(left, roundi(float(area.position.x) * sx) + 12)
			right = maxi(right, roundi(float(pixels.x - area.end.x) * sx) + 12)
			top = maxi(top, roundi(float(area.position.y) * sy) + 12)
			bottom = maxi(bottom, roundi(float(pixels.y - area.end.y) * sy) + 12)
	for side in ["left", "right", "top", "bottom"]:
		var amount: int = 14
		match side:
			"left": amount = left
			"right": amount = right
			"top": amount = top
			"bottom": amount = bottom
		_safe.add_theme_constant_override("margin_" + side, amount)
