extends RefCounted
## Pure, deterministic M2-2 target selection for the auto-battle data core.
## The returned Dictionary is a live unit reference owned by the caller.
## This module makes no RNG calls and never mutates opponents.
const MAX_THREAT: int = 1000000

static func initial_row(source: Dictionary, slot: int) -> String:
	var explicit_row: String = str(source.get("row", "")).to_upper()
	if explicit_row in ["FRONT", "BACK"]:
		return explicit_row
	var role: String = str(source.get("role", ""))
	if role in ["TANK", "WARRIOR", "MELEE", "DEFENDER"]:
		return "FRONT"
	if role in ["ASSASSIN", "MAGE", "ARCHER", "RANGED", "SUPPORT"]:
		return "BACK"
	return "FRONT" if slot < 2 else "BACK"

static func initial_threat(role: String) -> int:
	if role in ["TANK", "DEFENDER"]:
		return 100
	if role in ["WARRIOR", "MELEE"]:
		return 40
	return 10

static func choose(actor: Dictionary, opponents: Array, tick: int) -> Dictionary:
	var alive: Array = []
	for item in opponents:
		if typeof(item) == TYPE_DICTIONARY and int(item.get("hp", 0)) > 0:
			alive.append(item)
	if alive.is_empty():
		return {}

	## Valid live taunt is stronger than row, role, threat, or remaining HP.
	## The battle's public hook enforces at most one active taunt per side.
	for item in alive:
		if int(item.get("taunt_until_tick", 0)) > tick:
			return item

	var role: String = str(actor.get("role", ""))
	var focus_row: String = "BACK" if role == "ASSASSIN" else "FRONT"
	var candidates: Array = []
	for item in alive:
		if str(item.get("row", "FRONT")) == focus_row:
			candidates.append(item)
	if candidates.is_empty():
		candidates = alive

	var low_hp_priority: bool = role in ["ASSASSIN", "MAGE", "ARCHER", "RANGED"]
	var best: Dictionary = candidates[0]
	for i in range(1, candidates.size()):
		var candidate: Dictionary = candidates[i]
		if low_hp_priority:
			if int(candidate.get("hp", 0)) < int(best.get("hp", 0)):
				best = candidate
		elif int(candidate.get("threat", 0)) > int(best.get("threat", 0)):
			best = candidate
	## Strict comparisons keep first deployment order on ties.
	return best
