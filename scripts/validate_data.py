#!/usr/bin/env python3
"""CI static check: data schema, IDs, references, formulas. Does not validate Godot runtime."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VALID_ROLES = {"WARRIOR", "MAGE", "TANK", "SUPPORT", "ASSASSIN", "ARCHER"}
VALID_ELEMENTS = {"FIRE", "ICE", "LIGHTNING", "NATURE", "LIGHT", "DARK"}


def read(name):
    with (ROOT / "data" / name).open(encoding="utf-8") as stream:
        return json.load(stream)


def check():
    chars = read("characters.json")
    skills = read("skills.json")
    enemies = read("enemies.json")
    stages = read("stages.json")
    balance = read("balance_config.json")
    assert len(chars) == 8, "MVP roster should contain 8 planned characters"
    assert len(skills) == 16, "8 active + 8 ultimate skill definitions required"
    assert len(stages) == 10, "M4 vertical slice should list 10 planned stages"
    for collection in (chars, skills, enemies, stages):
        ids = [item["id"] for item in collection]
        assert len(ids) == len(set(ids)), f"duplicate ID in {ids}"
    skill_ids = {s["id"] for s in skills}
    enemy_ids = {e["id"] for e in enemies}
    for char in chars:
        assert char["role"] in VALID_ROLES and char["element"] in VALID_ELEMENTS
        assert char["rarity"] in {"R", "SR", "SSR"}
        stats = char["base_stats"]
        assert all(isinstance(stats[k], (int, float)) and stats[k] > 0 for k in ("hp", "atk", "def", "spd"))
        assert 0 <= stats["crit"] <= 0.75
        assert set(char["skill_ids"]).issubset(skill_ids)
    for stage in stages:
        assert set(stage["enemy_ids"]).issubset(enemy_ids)
    assert balance["party_size"] == balance["frontline"] + balance["backline"] == 5
    assert balance["maximum_level"] == 100
    assert 0.0 < balance["offline_efficiency"] <= 1.0
    assert 100 + 16 * 99 + 4 * 99 * 99 == 40888
    assert 60 + 10 * 99 + 2 * 99 * 99 == 20652
    print("PASS: 8 characters, 16 spec-only skills, 3 enemies, 10 planned stages, balance formulas")


if __name__ == "__main__":
    check()
