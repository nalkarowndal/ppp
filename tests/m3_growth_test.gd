extends SceneTree
## M3-1 growth and economy transactions. This suite is intentionally independent of M1 debug saves.
const Repo = preload("res://scripts/core/data_repository.gd")
const Growth = preload("res://scripts/core/growth_system.gd")

var failures: Array[String] = []

func _initialize() -> void:
	var characters: Array = Repo.load_array("res://data/characters.json")
	_expect(characters.size() == 8, "static hero fixtures")
	if characters.size() != 8:
		_finish()
		return

	var hero: Dictionary = Growth.new_hero("CHR_ARIA")
	var wallet: Dictionary = {"gold": 10000000, "xp_crystals": 10000000, "ascension_stones": 500}
	var original_hero: Dictionary = hero.duplicate(true)
	var original_wallet: Dictionary = wallet.duplicate(true)
	_expect(int(hero.get("level", 0)) == 1 and int(hero.get("stars", 0)) == 1, "new character starts at level one and one star")
	_expect(Growth.level_cap(1) == 20 and Growth.level_cap(5) == 100, "ascending level caps")

	var first: Dictionary = Growth.try_level_up(hero, wallet)
	_expect(bool(first.get("ok", false)), "level one upgrade")
	_expect(int(first["hero"]["level"]) == 2, "level increases exactly once")
	_expect(int(first["wallet"]["xp_crystals"]) == int(wallet["xp_crystals"]) - 120, "experience cost 120")
	_expect(int(first["wallet"]["gold"]) == int(wallet["gold"]) - 72, "gold cost 72")
	_expect(hero == original_hero and wallet == original_wallet, "transactions do not mutate caller state")

	var broke: Dictionary = {"gold": 71, "xp_crystals": 119, "ascension_stones": 0}
	var failed: Dictionary = Growth.try_level_up(hero, broke)
	_expect(not bool(failed.get("ok", true)) and failed["hero"] == hero and failed["wallet"] == broke, "insufficient currencies never partially debit")
	_expect(not bool(Growth.try_ascend(hero, wallet)["ok"]), "ascension requires the current level cap")

	var capped: Dictionary = {"id": "CHR_ARIA", "level": 20, "stars": 1}
	_expect(not bool(Growth.try_level_up(capped, wallet)["ok"]), "star one stops at level 20")
	var ascend: Dictionary = Growth.try_ascend(capped, wallet)
	_expect(bool(ascend.get("ok", false)) and int(ascend["hero"]["stars"]) == 2, "one-to-two-star ascension")
	_expect(int(ascend["wallet"]["ascension_stones"]) == 495 and int(ascend["wallet"]["gold"]) == int(wallet["gold"]) - 1000, "ascension cost is atomic")
	var stats: Dictionary = Growth.stats_for(ascend["hero"], characters[0])
	_expect(int(stats.get("hp", 0)) == 1457, "level 20, two-star HP formula")
	_expect(float(stats.get("spd", 0)) == 105.0, "SPD stat does not scale with levels")
	_expect(Growth.stats_for(hero, characters[1]).is_empty(), "character ID mismatch rejected")
	_expect(int(characters[0]["base_stats"]["hp"]) == 950, "base character data never mutated")

	_expect(not bool(Growth.try_level_up({"id": "CHR_ARIA", "level": 99, "stars": 1}, wallet)["ok"]), "impossible level/star state rejected")
	_expect(not bool(Growth.try_level_up(hero, {"gold": -1, "xp_crystals": 999, "ascension_stones": 1})["ok"]), "invalid wallet rejected")
	_expect(not bool(Growth.try_level_up(hero, {"gold": 100000, "xp_crystals": 100000})["ok"]), "incomplete wallet rejected")
	_expect(Growth.new_hero("").is_empty(), "empty character ID rejected")

	var all_hero: Dictionary = Growth.new_hero("CHR_ARIA")
	var rich: Dictionary = {"gold": 2000000, "xp_crystals": 2000000, "ascension_stones": 500}
	var spent_xp := 0
	var spent_gold_levels := 0
	var spent_gold_ascend := 0
	var spent_stones := 0
	for star in range(1, 6):
		while int(all_hero["level"]) < Growth.level_cap(star):
			var before_level: int = int(all_hero["level"])
			var before_gold: int = int(rich["gold"])
			var before_xp: int = int(rich["xp_crystals"])
			var step: Dictionary = Growth.try_level_up(all_hero, rich)
			if not bool(step.get("ok", false)):
				_expect(false, "every legal level upgrade works")
				_finish()
				return
			all_hero = step["hero"]
			rich = step["wallet"]
			spent_xp += before_xp - int(rich["xp_crystals"])
			spent_gold_levels += before_gold - int(rich["gold"])
			_expect(int(all_hero["level"]) == before_level + 1, "no duplicate level-up")
		if star < 5:
			var before_gold: int = int(rich["gold"])
			var before_stones: int = int(rich["ascension_stones"])
			var promotion: Dictionary = Growth.try_ascend(all_hero, rich)
			if not bool(promotion.get("ok", false)):
				_expect(false, "every legal ascension works")
				_finish()
				return
			all_hero = promotion["hero"]
			rich = promotion["wallet"]
			spent_gold_ascend += before_gold - int(rich["gold"])
			spent_stones += before_stones - int(rich["ascension_stones"])
	_expect(int(all_hero["level"]) == 100 and int(all_hero["stars"]) == 5, "level 100 at five stars")
	_expect(spent_xp == 1402500 and spent_gold_levels == 712140, "complete level 1 to 100 cost")
	_expect(spent_gold_ascend == 52000 and spent_stones == 160, "all ascension costs exactly once")
	_expect(not bool(Growth.try_level_up(all_hero, rich)["ok"]), "maximum level never charges")
	_expect(not bool(Growth.try_ascend(all_hero, rich)["ok"]), "maximum stars never charge")
	_finish()

func _expect(condition: bool, test_name: String) -> void:
	if not condition:
		failures.append(test_name)

func _finish() -> void:
	if not failures.is_empty():
		for message in failures:
			push_error("M3-1 FAIL: " + message)
		quit(1)
		return
	print("M3-1 GROWTH PASS: 1..100 levels, five stars, atomic costs, immutable data, caps and stats")
	quit(0)
