extends RefCounted
## M2-5 pure, read-only battle snapshot presentation; no combat state mutations.
const STATUS_NAMES: Dictionary = {
	"BURN": "화상", "POISON": "독", "SLOW": "감속", "FREEZE": "빙결",
	"DEF_DOWN": "방어 감소", "DEF_UP": "방어 증가", "REGEN": "재생", "TAUNT": "도발"
}

static func hp_text(unit: Dictionary) -> String:
	return "HP %d/%d" % [int(unit.get("hp", 0)), int(unit.get("max_hp", 1))]

static func battle_title(state: Dictionary) -> String:
	var phase: String = str(state.get("state", "idle"))
	var label: String = "전투 중"
	match phase:
		"victory":
			label = "승리 · 전투 종료"
		"defeat":
			label = "패배 · 전투 종료"
		"invalid":
			label = "편성 오류"
		"idle":
			label = "전투 준비"
	var seconds: int = int(state.get("ticks", 0)) / 20
	return "%s  ·  %02d:%02d" % [label, int(seconds / 60), seconds % 60]

static func status_text(unit: Dictionary, tick: int) -> String:
	var statuses: Dictionary = unit.get("statuses", {})
	if statuses.is_empty():
		return "상태 없음"
	var fragments := PackedStringArray()
	for id in statuses.keys():
		var entry: Dictionary = statuses[id]
		var remaining: int = maxi(0, int(entry.get("expires_tick", tick)) - tick)
		var label: String = str(STATUS_NAMES.get(str(id), str(id)))
		var stacks: int = int(entry.get("stacks", 1))
		if stacks > 1:
			label += "×%d" % stacks
		fragments.append("%s %d초" % [label, maxi(1, ceili(float(remaining) / 20.0))])
	return " · ".join(fragments)

static func log_text(events: Array, _state: Dictionary) -> String:
	if events.is_empty():
		return "전투를 시작했습니다. 궁극기 AUTO를 변경할 수 있습니다."
	var lines := PackedStringArray()
	for i in range(maxi(0, events.size() - 3), events.size()):
		var event: Dictionary = events[i]
		var kind: String = str(event.get("type", ""))
		var actor: String = str(event.get("actor_id", ""))
		var target: String = str(event.get("target_id", ""))
		var tick: int = int(event.get("tick", 0))
		var detail: String = ""
		match kind:
			"basic_attack":
				detail = "%s 공격 → %s" % [actor, target]
			"skill_cast":
				detail = "%s %s 사용" % [actor, "궁극기" if str(event.get("category", "")) == "ULTIMATE" else "스킬"]
			"skill_hit":
				detail = "%s 스킬 명중 (%d)" % [target, int(event.get("hp_loss", 0))]
			"status_tick":
				var status_label: String = str(STATUS_NAMES.get(str(event.get("status_id", "")), str(event.get("status_id", ""))))
				detail = "%s %s %d" % [target, status_label, int(event.get("amount", 0))]
			"heal":
				detail = "%s 회복 +%d" % [target, int(event.get("amount", 0))]
			"shield":
				detail = "%s 보호막 +%d" % [target, int(event.get("amount", 0))]
			"status_applied":
				detail = "%s 상태: %s" % [target, str(STATUS_NAMES.get(str(event.get("status_id", "")), str(event.get("status_id", ""))))]
			"status_expired":
				detail = "%s 효과 종료" % target
			_:
				detail = "%s · %s" % [actor, kind]
		lines.append("%d초  %s" % [int(tick / 20), detail])
	return "\n".join(lines)
