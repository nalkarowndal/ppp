# M2-3 Skill Runtime Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a deterministic, testable 8-active/8-ultimate primary effect runtime on top of M2-2.
**Architecture:** `SkillResolver` reads skill definitions and selects candidates; `Battle` owns ticks, RNG, cooldowns, energy and events. Split status applications into M2-4, record explicit deferred secondary-effect events.
**Tech Stack:** Godot 4.7.2 GDScript, JSON, GitHub Actions headless tests.
**Spec:** docs/superpowers/specs/2026-11-11-m2-3-skill-runtime.md

## Global constraints
- Work only on `feature/m2-3-skill-runtime`, based on `feature/m2-2-target-ai`; create Draft stacked PR.
- Preserve M1 UI/debug save, no physical-device QA claims, don't merge `main`.
- 20Hz tick, RNG seed replay, 1x/2x/3x equivalence, source JSON immutability and existing event fields.
- 16 skills: direct primaries in M2-3; DOT/CC/regen/DEF status implementations deferred to M2-4.

## Review focus
- Manual ultimate shouldn't fire when energy is 99 or caster dead.
- AoE attacks shouldn't repeatedly target dead units; overkill threat should remain HP-loss based.
- Heals can't exceed max HP and shields must absorb damage before HP.
- Cooldown starts at cast tick, not at readiness detection, and applies at the exact 20Hz boundary.
- Unknown ID or invalid team must never consume energy or corrupt dictionaries.

### Task 1: Add failing headless tests and CI
**Files:** `tests/m2_skill_runtime_test.gd`, `.github/workflows/godot-m2-combat.yml`.
**Interfaces:** `Battle.setup`, `Battle.step_ticks`, `Battle.snapshot`, `Battle.set_auto_ultimate(bool)`, `Battle.cast_ultimate(team:String,id:String) -> bool`.
- [ ] Test 16 skill primaries, cooldown, manual/auto, AoE, healing/shield/taunt, consistent snapshots/seed.
- [ ] Run Godot headless M2 CI; verify specific M2-3 RED while M2-1 and M2-2 remain green.
- [ ] Commit tests before implementation.

### Task 2: Resolver and core effect implementation
**Files:** `scripts/combat/skill_resolver.gd`, `scripts/combat/auto_battle_core.gd`.
**Interfaces:** `SkillResolver.catalog()`, `SkillResolver.skill_for(actor,category,catalog)`, `SkillResolver.targets(actor,skill,allies,enemies,tick)`.
- [ ] Load JSON safely, enforce valid categories/owned skill IDs and supported effect types.
- [ ] Implement action priority and energy/cooldown/manual pathways with no dual actions.
- [ ] Implement all 16 primary effects and deferred status events.
- [ ] Execute official M2 headless workflow until GREEN; fix failures, not assertions.

### Task 3: Verification and draft review
**Files:** `docs/qa/m2_3_skill_runtime.md`, `README.md`, `docs/04_roadmap/development_roadmap.md`.
- [ ] Verify final HEAD M2-1/M2-2/M2-3 logs, static and platform CI truthfully.
- [ ] Inspect changed files for edge cases; document unresolved M2-4/5 and M1 gates.
- [ ] Create Draft PR against M2-2, not main; do not call whole M2 finished.