extends RefCounted
## M3-1 pure growth transactions. Character definitions and input state are immutable.
const Progression = preload("res://scripts/core/progression.gd")

const MAX_LEVEL: int = 100
const MAX_STARS: int = 5
const LEVEL_CAPS = [20, 40, 60, 80, 100]
const STAR_MULTIPLIERS = [1.0, 1.04, 1.09, 1.15, 1.22]
const ASCENSION_STONES = [0, 5, 15, 40, 100]
const ASCENSION_GOLD = [0, 1000, 4000, 12000, 35000]
const CURRENCIES = ["gold", "xp_crystals", "ascension_stones"]

static func new_hero(character_id: String) -> Dictionary:
	if character_id.strip_edges().is_empty():
		return {}
	return {"id": character_id, "level": 1, "stars": 1}

static func level_cap(stars: int) -> int:
	if stars < 1 or stars > MAX_STARS:
		return 0
	return int(LEVEL_CAPS[stars - 1])

## Experience crystals are denominated in XP units for the initial economy.
## Every result owns a new snapshot; errors also leave inputs untouched.
static func try_level_up(hero: Dictionary, wallet: Dictionary) -> Dictionary:
	if not _valid_hero(hero) or not _valid_wallet(wallet):
		return _result(false, "invalid_state", hero, wallet, {})
	var level: int = int(hero["level"])
	var stars: int = int(hero["stars"])
	if level >= MAX_LEVEL:
		return _result(false, "maximum_level", hero, wallet, {})
	if level >= level_cap(stars):
		return _result(false, "ascension_required", hero, wallet, {})
	var cost: Dictionary = {"xp_crystals": Progression.experience_cost(level), "gold": Progression.gold_cost(level)}
	if not _affordable(wallet, cost):
		return _result(false, "insufficient_currency", hero, wallet, cost)
	var next_hero: Dictionary = hero.duplicate(true)
	var next_wallet: Dictionary = wallet.duplicate(true)
	next_hero["level"] = level + 1
	for key in cost:
		next_wallet[key] = int(next_wallet[key]) - int(cost[key])
	return _result(true, "ok", next_hero, next_wallet, cost)

## Promotion requires reaching the current level cap; level stays unchanged.
static func try_ascend(hero: Dictionary, wallet: Dictionary) -> Dictionary:
	if not _valid_hero(hero) or not _valid_wallet(wallet):
		return _result(false, "invalid_state", hero, wallet, {})
	var stars: int = int(hero["stars"])
	if stars >= MAX_STARS:
		return _result(false, "maximum_stars", hero, wallet, {})
	if int(hero["level"]) != level_cap(stars):
		return _result(false, "level_cap_required", hero, wallet, {})
	var cost: Dictionary = {"ascension_stones": int(ASCENSION_STONES[stars]), "gold": int(ASCENSION_GOLD[stars])}
	if not _affordable(wallet, cost):
		return _result(false, "insufficient_currency", hero, wallet, cost)
	var next_hero: Dictionary = hero.duplicate(true)
	var next_wallet: Dictionary = wallet.duplicate(true)
	next_hero["stars"] = stars + 1
	for key in cost:
		next_wallet[key] = int(next_wallet[key]) - int(cost[key])
	return _result(true, "ok", next_hero, next_wallet, cost)

## Equipment bonuses are deferred to M3-2. SPD/CRIT/CRIT_DMG stay unchanged.
static func stats_for(hero: Dictionary, character: Dictionary) -> Dictionary:
	if not _valid_hero(hero) or str(character.get("id", "")) != str(hero["id"]):
		return {}
	var base: Variant = character.get("base_stats", null)
	if typeof(base) != TYPE_DICTIONARY:
		return {}
	var base_stats: Dictionary = base
	var stats: Dictionary = base_stats.duplicate(true)
	for key in ["hp", "atk", "def"]:
		if not base_stats.has(key):
			return {}
		if typeof(base_stats[key]) != TYPE_INT and typeof(base_stats[key]) != TYPE_FLOAT:
			return {}
		if float(base_stats[key]) < 0.0:
			return {}
		stats[key] = Progression.stat_at_level(int(base_stats[key]), int(hero["level"]), float(STAR_MULTIPLIERS[int(hero["stars"]) - 1]))
	return stats

static func _valid_hero(hero: Dictionary) -> bool:
	if typeof(hero.get("id", null)) != TYPE_STRING or str(hero.get("id", "")).strip_edges().is_empty():
		return false
	if typeof(hero.get("level", null)) != TYPE_INT or typeof(hero.get("stars", null)) != TYPE_INT:
		return false
	var level: int = int(hero["level"])
	var stars: int = int(hero["stars"])
	return stars >= 1 and stars <= MAX_STARS and level >= 1 and level <= level_cap(stars)

static func _valid_wallet(wallet: Dictionary) -> bool:
	for key in CURRENCIES:
		if not wallet.has(key) or typeof(wallet[key]) != TYPE_INT or int(wallet[key]) < 0:
			return false
	return true

static func _affordable(wallet: Dictionary, cost: Dictionary) -> bool:
	for key in cost:
		if int(wallet.get(key, -1)) < int(cost[key]):
			return false
	return true

static func _result(success: bool, reason: String, hero: Dictionary, wallet: Dictionary, cost: Dictionary) -> Dictionary:
	return {
		"ok": success,
		"reason": reason,
		"hero": hero.duplicate(true),
		"wallet": wallet.duplicate(true),
		"cost": cost.duplicate(true)
	}
