extends RefCounted
## M2-3 non-mutating target resolution. Timed statuses belong to M2-4.
const TargetAI = preload("res://scripts/combat/target_selector.gd")

static func select(actor: Dictionary, skill: Dictionary, allies: Array, enemies: Array, tick: int) -> Array:
	var mode: String = str(skill.get("target", ""))
	var friendly: Array = allies if str(actor.get("team", "")) == "ally" else enemies
	var hostile: Array = enemies if str(actor.get("team", "")) == "ally" else allies
	if mode == "SELF":
		return [actor] if int(actor.get("hp", 0)) > 0 else []
	if mode == "ALLY_LOW_HP":
		var weakest: Dictionary = {}
		for unit in friendly:
			if int(unit.get("hp", 0)) <= 0:
				continue
			if weakest.is_empty() or float(unit["hp"]) / float(maxi(1, int(unit["max_hp"]))) < float(weakest["hp"]) / float(maxi(1, int(weakest["max_hp"]))):
				weakest = unit
		return [] if weakest.is_empty() else [weakest]
	if mode == "ALL_ALLIES":
		return _living(friendly)
	if mode == "ALL_ENEMIES":
		return _living(hostile)

	var targets: Array = _living(hostile)
	if targets.is_empty():
		return []
	if mode == "ENEMY_BACK":
		var taunted: Dictionary = {}
		for target in targets:
			if int(target.get("taunt_until_tick", 0)) > tick:
				taunted = target
				break
		if not taunted.is_empty():
			return [taunted]
		var backline: Array = []
		for target in targets:
			if str(target.get("row", "")) == "BACK":
				backline.append(target)
		if not backline.is_empty():
			targets = backline
		var smallest: Dictionary = targets[0]
		for target in targets:
			if int(target["hp"]) < int(smallest["hp"]):
				smallest = target
		return [smallest]

	var first: Dictionary = TargetAI.choose(actor, hostile, tick)
	if first.is_empty():
		return []
	if mode == "SINGLE_ENEMY":
		return [first]
	if mode == "UP_TO_3_ENEMIES":
		var chosen: Array = [first]
		for unit in targets:
			if unit != first and chosen.size() < 3:
				chosen.append(unit)
		return chosen
	return []

static func _living(units: Array) -> Array:
	var result: Array = []
	for unit in units:
		if int(unit.get("hp", 0)) > 0:
			result.append(unit)
	return result
