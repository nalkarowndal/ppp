extends Control
## M3-6 native Godot portrait UI. Separate scene so M1 debug and M2 combat
## interactions keep their original visual geometry and QA targets.
const Repo = preload("res://scripts/core/data_repository.gd")
const Model = preload("res://scripts/ui/m3_progression_controller.gd")
const Growth = preload("res://scripts/core/growth_system.gd")
const Gear = preload("res://scripts/core/equipment_system.gd")
const Idle = preload("res://scripts/core/offline_rewards.gd")
const Store = preload("res://scripts/core/profile_store.gd")

const INK := Color("#101726")
const PANEL := Color("#1C2840")
const PANEL_SOFT := Color("#263750")
const BORDER := Color("#536782")
const GOLD := Color("#DCC18A")
const IVORY := Color("#F7F1E8")
const MUTED := Color("#B8C5D6")
const POSITIVE := Color("#A5D6C3")

@export var save_path: String = Store.SAVE_PATH

var _model = Model.new()
var _ready_ok: bool = false
var _safe: MarginContainer
var _hero_name: Label
var _wallet_label: Label
var _status_label: Label
var _stats_label: Label
var _growth_detail: Label
var _slot_summary: Label
var _idle_summary: Label
var _inventory_rows: VBoxContainer
var _slot_picker: OptionButton
var _level_button: Button
var _ascend_button: Button
var _unequip_button: Button
var _claim_button: Button
var _pages: Array[ScrollContainer] = []
var _tabs: Array[Button] = []
var _current_tab: int = 0
var _idle_dialog: ConfirmationDialog

func _ready() -> void:
	_setup_theme()
	_build()
	var result: Dictionary = _model.initialize(save_path)
	_ready_ok = bool(result.get("ok", false))
	if _ready_ok:
		# In the actual exported game, the project Autoload exists. Standalone
		# --script Godot integration tests do not instantiate project Autoloads.
		var session_node: Node = get_tree().root.get_node_or_null("M3Session")
		if session_node != null:
			session_node.call("attach", _model)
			session_node.connect("application_resumed", Callable(self, "_on_session_resumed"))
	if not _ready_ok:
		_status_label.text = "저장 데이터를 열 수 없습니다: " + str(result.get("reason", "unknown"))
		_level_button.disabled = true
		_ascend_button.disabled = true
		_unequip_button.disabled = true
		_claim_button.disabled = true
	else:
		_status_label.text = "성장 데이터를 안전하게 불러왔습니다."
		_refresh_all()
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)
	print("M3_UI_READY: growth/equipment/idle scene initialized, storage_ok=%d" % int(_ready_ok))

func _on_session_resumed() -> void:
	if not _ready_ok:
		return
	_refresh_all()
	var preview: Dictionary = _model.preview_idle(_now_unix())
	if bool(preview.get("ok", false)) and int(preview["rewards"].get("gold", 0)) > 0:
		_idle_dialog.dialog_text = "방치 보상이 준비됐습니다.\n골드 %d  ·  경험치 결정 %d\n수령하시겠습니까?" % [int(preview["rewards"]["gold"]), int(preview["rewards"]["xp_crystals"])]
		_idle_dialog.popup_centered(Vector2i(320, 170))

func _now_unix() -> int:
	return int(floor(Time.get_unix_time_from_system()))

func _setup_theme() -> void:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Noto Sans CJK KR", "Malgun Gothic", "NanumGothic", "sans-serif"])
	var t := Theme.new()
	t.default_font = f
	theme = t

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = INK
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_safe = MarginContainer.new()
	_safe.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_safe)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	_safe.add_child(stack)

	var top := _section(stack)
	var title := _label(top, "ASTRAL CHRONICLE", 22, GOLD)
	title.name = "M3PageTitle"
	_label(top, "성장 · 장비 · 방치 보상", 12, MUTED)

	var hero_row := HBoxContainer.new()
	hero_row.add_theme_constant_override("separation", 6)
	stack.add_child(hero_row)
	var prev := _button(hero_row, "‹", "M3HeroPrev")
	prev.custom_minimum_size.x = 52
	prev.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	prev.pressed.connect(_shift_hero.bind(-1))
	_hero_name = _label(hero_row, "동료", 15, IVORY)
	_hero_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hero_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var next := _button(hero_row, "›", "M3HeroNext")
	next.custom_minimum_size.x = 52
	next.size_flags_horizontal = Control.SIZE_SHRINK_END
	next.pressed.connect(_shift_hero.bind(1))

	_wallet_label = _label(stack, "G 0 · XP 0 · 승급석 0 · 강화석 0", 12, MUTED)
	_wallet_label.name = "M3WalletLabel"

	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 6)
	stack.add_child(nav)
	for pair in [
		["성장", "M3GrowthTab"],
		["장비", "M3EquipmentTab"],
		["방치", "M3IdleTab"]
	]:
		var tab := _button(nav, str(pair[0]), str(pair[1]))
		tab.pressed.connect(_show_tab.bind(_tabs.size()))
		_tabs.append(tab)

	var content_holder := Control.new()
	content_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(content_holder)
	for i in range(3):
		var sc := ScrollContainer.new()
		sc.name = ["M3GrowthScroll", "M3InventoryScroll", "M3IdleScroll"][i]
		sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sc.visible = i == 0
		content_holder.add_child(sc)
		_pages.append(sc)
	var growth := VBoxContainer.new()
	growth.add_theme_constant_override("separation", 12)
	growth.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pages[0].add_child(growth)
	_build_growth(growth)
	var equipment := VBoxContainer.new()
	equipment.add_theme_constant_override("separation", 12)
	equipment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pages[1].add_child(equipment)
	_build_equipment(equipment)
	var idle := VBoxContainer.new()
	idle.add_theme_constant_override("separation", 12)
	idle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pages[2].add_child(idle)
	_build_idle(idle)

	_status_label = _label(stack, "불러오는 중…", 12, POSITIVE)
	_status_label.name = "M3StatusLabel"
	_status_label.custom_minimum_size.y = 34
	var bottom := _button(stack, "‹  개발 화면으로 돌아가기", "M3BackButton")
	bottom.pressed.connect(func() -> void:
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	)

	_idle_dialog = ConfirmationDialog.new()
	_idle_dialog.name = "M3IdleRewardDialog"
	_idle_dialog.title = "방치 보상"
	_idle_dialog.confirmed.connect(_on_claim_pressed)
	add_child(_idle_dialog)

func _build_growth(root: VBoxContainer) -> void:
	var summary := _section(root)
	_label(summary, "동료 능력치", 16, GOLD)
	_stats_label = _label(summary, "", 15, IVORY)
	_growth_detail = _label(summary, "", 12, MUTED)
	var progression := _section(root)
	_label(progression, "육성", 16, GOLD)
	_level_button = _button(progression, "레벨 올리기", "M3LevelButton")
	_level_button.pressed.connect(_on_level_pressed)
	_ascend_button = _button(progression, "승급", "M3AscendButton")
	_ascend_button.pressed.connect(_on_ascend_pressed)
	_label(progression, "필요 재화는 자동으로 차감됩니다. 획득 경로는 추후 스테이지 보상과 연결됩니다.", 12, MUTED)

func _build_equipment(root: VBoxContainer) -> void:
	var loadout := _section(root)
	_label(loadout, "장비 슬롯", 16, GOLD)
	_slot_summary = _label(loadout, "", 13, IVORY)
	_slot_picker = OptionButton.new()
	_slot_picker.name = "M3SlotPicker"
	_slot_picker.custom_minimum_size.y = 52
	_slot_picker.add_theme_font_size_override("font_size", 14)
	for text in ["무기", "방어구", "장신구 I", "장신구 II"]:
		_slot_picker.add_item(text)
	loadout.add_child(_slot_picker)
	_unequip_button = _button(loadout, "선택 슬롯 장비 해제", "M3UnequipButton")
	_unequip_button.pressed.connect(_on_unequip_pressed)
	_slot_picker.item_selected.connect(func(_index: int) -> void:
		_refresh_all()
	)
	var items := _section(root)
	_label(items, "보유 장비 · 장착 / 강화", 16, GOLD)
	_label(items, "장착할 슬롯을 위에서 고른 뒤 장착하세요. 이미 장착된 아이템은 재장착할 수 없습니다.", 12, MUTED)
	_inventory_rows = VBoxContainer.new()
	_inventory_rows.name = "M3InventoryRows"
	_inventory_rows.add_theme_constant_override("separation", 9)
	items.add_child(_inventory_rows)

func _build_idle(root: VBoxContainer) -> void:
	var panel := _section(root)
	_label(panel, "오프라인 보상", 17, GOLD)
	_label(panel, "최대 8시간 · 스테이지별 생산량의 80%", 13, MUTED)
	_idle_summary = _label(panel, "", 15, IVORY)
	_claim_button = _button(panel, "방치 보상 수령", "M3IdleClaimButton")
	_claim_button.pressed.connect(_on_claim_pressed)
	_label(panel, "보상은 마지막 종료 시점의 스테이지로 계산됩니다. 실제 스테이지 클리어 보상 연동은 M4에서 확장됩니다.", 12, MUTED)

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
	_safe.add_theme_constant_override("margin_left", left)
	_safe.add_theme_constant_override("margin_right", right)
	_safe.add_theme_constant_override("margin_top", top)
	_safe.add_theme_constant_override("margin_bottom", bottom)

func _section(parent: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	var surface := StyleBoxFlat.new()
	surface.bg_color = PANEL
	surface.border_color = BORDER
	surface.set_corner_radius_all(12)
	surface.set_border_width_all(1)
	panel.add_theme_stylebox_override("panel", surface)
	parent.add_child(panel)
	var padding := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		padding.add_theme_constant_override("margin_" + side, 12)
	panel.add_child(padding)
	var contents := VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_theme_constant_override("separation", 8)
	padding.add_child(contents)
	return contents

func _label(parent: Node, value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Node, value: String, node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = value
	button.custom_minimum_size = Vector2(0, 52)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", IVORY)
	var base := StyleBoxFlat.new()
	base.bg_color = PANEL_SOFT
	base.border_color = BORDER
	base.set_border_width_all(1)
	base.set_corner_radius_all(10)
	button.add_theme_stylebox_override("normal", base)
	var hover := base.duplicate()
	hover.bg_color = Color("#364F6C")
	button.add_theme_stylebox_override("hover", hover)
	var pressed := base.duplicate()
	pressed.bg_color = Color("#435A72")
	button.add_theme_stylebox_override("pressed", pressed)
	parent.add_child(button)
	return button

func _show_tab(index: int) -> void:
	_current_tab = index
	for i in range(_pages.size()):
		_pages[i].visible = i == index
	for i in range(_tabs.size()):
		_tabs[i].add_theme_color_override("font_color", GOLD if i == index else IVORY)
	if _ready_ok:
		_refresh_all()

func _shift_hero(step: int) -> void:
	if not _ready_ok:
		return
	var chars: Array = _model.character_definitions()
	var current: int = 0
	for i in range(chars.size()):
		if str(chars[i]["id"]) == _model.selected_hero_id():
			current = i
			break
	var candidate: String = str(chars[posmod(current + step, chars.size())]["id"])
	_model.select_hero(candidate)
	_status_label.text = "선택한 동료: " + str(_model.selected_character().get("name", candidate))
	_refresh_all()

func _refresh_all() -> void:
	if not _ready_ok:
		return
	var state: Dictionary = _model.snapshot()
	var character: Dictionary = _model.selected_character()
	var hero: Dictionary = _model.selected_hero()
	var wallet: Dictionary = state["economy_state"]["wallet"]
	var stats: Dictionary = _model.selected_stats()
	_hero_name.text = "%s  ·  %s / %s" % [
		str(character.get("name", "?")),
		str(character.get("rarity", "")),
		str(character.get("role", ""))
	]
	_wallet_label.text = "골드 %d  |  XP %d\n승급석 %d  |  강화석 %d" % [
		int(wallet["gold"]), int(wallet["xp_crystals"]),
		int(wallet["ascension_stones"]), int(wallet["enhancement_stones"])
	]
	_stats_label.text = "레벨 %d / %d    ★ %d\nHP %d    ATK %d    DEF %d" % [
		int(hero["level"]), Growth.level_cap(int(hero["stars"])), int(hero["stars"]),
		int(stats.get("hp", 0)), int(stats.get("atk", 0)), int(stats.get("def", 0))
	]
	var level_op: Dictionary = Growth.try_level_up(hero, wallet)
	var ascend_op: Dictionary = Growth.try_ascend(hero, wallet)
	_level_button.disabled = not bool(level_op["ok"])
	_ascend_button.disabled = not bool(ascend_op["ok"])
	_growth_detail.text = "레벨업: " + _reason(str(level_op["reason"])) + "\n승급: " + _reason(str(ascend_op["reason"]))
	var loadout: Dictionary = state["loadouts"][_model.selected_hero_id()]
	var inventory: Dictionary = state["economy_state"]["inventory"]
	var slot_lines: PackedStringArray = []
	var slot_names: Array = ["무기", "방어구", "장신구 I", "장신구 II"]
	for i in range(Gear.SLOTS.size()):
		var slot: String = str(Gear.SLOTS[i])
		var uid: String = str(loadout[slot])
		var gear_name: String = "비어 있음"
		if not uid.is_empty() and inventory.has(uid):
			var item: Dictionary = inventory[uid]
			var entry: Dictionary = _model.equipment_catalog().get(item["template_id"], {})
			gear_name = "%s +%d" % [str(entry.get("name", uid)), int(item["enhance_level"])]
		slot_lines.append("%s  ·  %s" % [str(slot_names[i]), gear_name])
	_slot_summary.text = "\n".join(slot_lines)
	var selected_slot: int = clampi(_slot_picker.selected, 0, Gear.SLOTS.size() - 1)
	_unequip_button.disabled = str(loadout[str(Gear.SLOTS[selected_slot])]).is_empty()
	_refresh_inventory(inventory)
	_refresh_idle()

func _refresh_inventory(inventory: Dictionary) -> void:
	for child in _inventory_rows.get_children():
		_inventory_rows.remove_child(child)
		child.queue_free()
	if inventory.is_empty():
		_label(_inventory_rows, "획득한 장비가 없습니다.\n스테이지 보상이 연결되면 여기에 표시됩니다.", 13, MUTED)
		return
	var catalog: Dictionary = _model.equipment_catalog()
	var sorted_ids: Array = inventory.keys()
	sorted_ids.sort()
	for uid in sorted_ids:
		var item: Dictionary = inventory[uid]
		var definition: Dictionary = catalog.get(str(item["template_id"]), {})
		var section: VBoxContainer = _section(_inventory_rows)
		_label(section, "%s · %s · +%d" % [
			str(definition.get("name", str(uid))),
			str(definition.get("rarity", "")),
			int(item["enhance_level"])
		], 13, IVORY)
		if not str(item["equipped_by"]).is_empty():
			_label(section, "장착 중: " + str(item["equipped_slot"]), 12, MUTED)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 7)
		section.add_child(row)
		var equip := _button(row, "장착", "M3Equip_" + str(uid))
		equip.disabled = not str(item["equipped_by"]).is_empty()
		equip.pressed.connect(_on_equip_pressed.bind(str(uid)))
		var enhance := _button(row, "강화", "M3Enhance_" + str(uid))
		enhance.disabled = int(item["enhance_level"]) >= Gear.enhancement_cap(str(definition.get("rarity", "")))
		enhance.pressed.connect(_on_enhance_pressed.bind(str(uid)))

func _refresh_idle() -> void:
	var preview: Dictionary = _model.preview_idle(_now_unix())
	if not bool(preview.get("ok", false)):
		_idle_summary.text = "기록된 방치 시간이 없습니다.\n게임을 종료하거나 백그라운드로 이동한 후 복귀해 주세요."
		_claim_button.disabled = true
		return
	var gold: int = int(preview["rewards"].get("gold", 0))
	var xp: int = int(preview["rewards"].get("xp_crystals", 0))
	_idle_summary.text = "인정 시간  %d / 28,800초\n획득 예정  골드 %d  ·  XP 결정 %d" % [
		int(preview["credited_seconds"]), gold, xp
	]
	_claim_button.disabled = gold <= 0 and xp <= 0

func _on_level_pressed() -> void:
	_apply_action(_model.level_selected(), "레벨업 완료")

func _on_ascend_pressed() -> void:
	_apply_action(_model.ascend_selected(), "승급 완료")

func _on_equip_pressed(uid: String) -> void:
	var i: int = clampi(_slot_picker.selected, 0, Gear.SLOTS.size() - 1)
	_apply_action(_model.equip_item(uid, str(Gear.SLOTS[i])), "장비를 장착했습니다")

func _on_unequip_pressed() -> void:
	var i: int = clampi(_slot_picker.selected, 0, Gear.SLOTS.size() - 1)
	_apply_action(_model.unequip_slot(str(Gear.SLOTS[i])), "장비를 해제했습니다")

func _on_enhance_pressed(uid: String) -> void:
	_apply_action(_model.enhance_item(uid), "장비를 강화했습니다")

func _on_claim_pressed() -> void:
	_apply_action(_model.claim_idle(_now_unix()), "방치 보상을 저장했습니다")

func _apply_action(outcome: Dictionary, success_text: String) -> void:
	if bool(outcome.get("ok", false)):
		_status_label.text = success_text
	else:
		_status_label.text = "처리 불가: " + _reason(str(outcome.get("reason", "unknown")))
	_refresh_all()

func _reason(reason: String) -> String:
	var names: Dictionary = {
		"ok": "사용 가능", "insufficient_currency": "재화 부족", "ascension_required": "승급 필요",
		"level_cap_required": "승급 조건: 현재 등급의 레벨 상한 필요",
		"maximum_level": "최대 레벨", "maximum_stars": "최대 등급",
		"maximum_enhancement": "최대 강화", "already_equipped": "이미 장착됨",
		"slot_mismatch": "슬롯 종류 불일치", "empty_slot": "장비가 없는 슬롯",
		"item_missing": "장비 없음", "no_reward": "현재 수령할 보상 없음",
		"clock_rollback": "기기 시간 역행 감지", "stale_revision": "저장 상태 갱신 필요",
		"no_checkpoint": "방치 기록 없음", "duplicate_event": "이미 수령한 보상",
		"invalid_state": "데이터 검증 실패", "corrupt": "저장 파일 손상"
	}
	return str(names.get(reason, reason))
