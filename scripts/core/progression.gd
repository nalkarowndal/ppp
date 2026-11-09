extends RefCounted
## Level-up cost functions from system_balance.md. Level is current level.

static func experience_cost(level: int) -> int:
	if level < 1 or level >= 100:
		return 0
	return 100 + 16 * level + 4 * level * level

static func gold_cost(level: int) -> int:
	if level < 1 or level >= 100:
		return 0
	return 60 + 10 * level + 2 * level * level

static func stat_at_level(base_stat: int, level: int, star_multiplier: float = 1.0) -> int:
	return int(floor(float(base_stat) * (1.0 + 0.025 * float(maxi(1, level) - 1)) * star_multiplier))

static func total_experience(from_level: int, to_level: int) -> int:
	var result := 0
	for level in range(from_level, mini(to_level, 100)):
		result += experience_cost(level)
	return result
