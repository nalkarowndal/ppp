extends RefCounted
## M2-4 pure fixed-tick status policy. No SceneTree, Timer, wall clock or RNG.
## The battle core owns damage/healing/events and drives these operations once
## per 20 Hz logical tick.
const PERIOD: int = 20
const STACK_LIMIT: int = 3
const DEBUFFS: Array = ["BURN", "POISON", "SLOW", "FREEZE", "DEF_DOWN"]
const BUFFS: Array = ["REGEN", "DEF_UP", "TAUNT"]
const TYPES: Array = ["BURN", "POISON", "SLOW", "FREEZE", "DEF_DOWN", "REGEN", "DEF_UP", "TAUNT"]

static func valid(kind: String) -> bool:
	return kind in TYPES

static func is_immune(unit: Dictionary, kind: String) -> bool:
	return kind in unit.get("immunities", [])

static func default_potency(kind: String) -> float:
	match kind:
		"BURN":
			return 0.02
		"POISON":
			return 0.01
		"SLOW":
			return 0.25
		"DEF_DOWN":
			return 0.20
		"DEF_UP":
			return 0.10
		"REGEN":
			return 0.03
		_:
			return 0.0

static func apply(unit: Dictionary, kind: String, tick: int, duration_ticks: int, potency: float = 0.0) -> bool:
	if not valid(kind) or duration_ticks <= 0 or int(unit.get("hp", 0)) <= 0 or is_immune(unit, kind):
		return false
	var statuses: Dictionary = unit.get("statuses", {})
	var magnitude: float = potency if potency > 0.0 else default_potency(kind)
	if statuses.has(kind):
		var old: Dictionary = statuses[kind]
		old["expires_tick"] = tick + duration_ticks
		old["potency"] = maxf(float(old.get("potency", 0.0)), magnitude)
		if kind in ["BURN", "POISON"]:
			old["stacks"] = mini(STACK_LIMIT, int(old["stacks"]) + 1)
		## Keep existing periodic schedule so refresh cannot postpone a pulse.
		statuses[kind] = old
	else:
		statuses[kind] = {
			"id": kind,
			"stacks": 1,
			"potency": magnitude,
			"expires_tick": tick + duration_ticks,
			"next_pulse_tick": tick + PERIOD if kind in ["BURN", "POISON", "REGEN"] else 0
		}
	unit["statuses"] = statuses
	return true

static func remove(unit: Dictionary, selector: String = "ALL") -> Array:
	var deleted: Array = []
	var statuses: Dictionary = unit.get("statuses", {})
	for kind in statuses.keys():
		if selector == "ALL" or selector == kind or (selector == "DEBUFF" and kind in DEBUFFS) or (selector == "BUFF" and kind in BUFFS):
			deleted.append(kind)
			statuses.erase(kind)
	unit["statuses"] = statuses
	return deleted

static func frozen(unit: Dictionary) -> bool:
	return unit.get("statuses", {}).has("FREEZE")

static func gauge_gain(unit: Dictionary) -> int:
	var potency: float = _potency(unit, "SLOW")
	return maxi(1, int(floor(float(unit.get("spd", 1)) * maxf(0.1, 1.0 - potency))))

static func effective_defense(unit: Dictionary) -> float:
	var base: float = float(unit.get("def", 0.0))
	return maxf(0.0, base * (1.0 + _potency(unit, "DEF_UP")) * (1.0 - minf(1.0, _potency(unit, "DEF_DOWN"))))

static func _potency(unit: Dictionary, kind: String) -> float:
	return float(unit.get("statuses", {}).get(kind, {}).get("potency", 0.0))

## Returns deterministic instructions without applying HP or shield changes.
## Pulses resolve in DOT-then-HOT order independent of status insertion order.
## At expiry tick a periodic pulse occurs before the status is removed.
static func advance(unit: Dictionary, tick: int) -> Array:
	var statuses: Dictionary = unit.get("statuses", {})
	var instructions: Array = []
	for kind in ["BURN", "POISON", "REGEN"]:
		if not statuses.has(kind):
			continue
		var state: Dictionary = statuses[kind]
		if tick >= int(state["next_pulse_tick"]) and tick <= int(state["expires_tick"]):
			var amount: int = maxi(1, int(floor(float(unit["max_hp"]) * float(state["potency"]) * float(state["stacks"]))))
			instructions.append({
				"kind": "pulse",
				"status_id": kind,
				"amount": amount,
				"heal": kind == "REGEN",
				"stacks": int(state["stacks"])
			})
			state["next_pulse_tick"] = int(state["next_pulse_tick"]) + PERIOD
			statuses[kind] = state
	for kind in statuses.keys():
		var state: Dictionary = statuses[kind]
		if tick >= int(state["expires_tick"]):
			statuses.erase(kind)
			instructions.append({"kind": "expired", "status_id": kind})
	unit["statuses"] = statuses
	return instructions
