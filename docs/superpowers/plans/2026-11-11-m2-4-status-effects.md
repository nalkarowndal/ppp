# M2-4 Status Effects Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:executing-plans. Tests first (RED), implement smallest functionality (GREEN), review against spec, then create Draft PR.

**Goal:** Add fixed-tick status damage/control/stat modifiers and complete M2-3 skill hookups without breaking older regressions.
**Architecture:** `scripts/combat/status_effects.gd` is a policy module manipulating per-unit runtime dictionaries only; `auto_battle_core.gd` consumes status pulse instructions, applies shield/HP, gates actions and calculates effective DEF. Statuses never use wall-clock timers or random APIs.
**Tech Stack:** Godot 4.7.2, GDScript, GitHub Actions Linux import/headless/Windows Android package regressions.
**Spec:** docs/superpowers/specs/2026-11-11-m2-4-status-effects.md

## Global Constraints
- Branch `feature/m2-4-status-effects` stacked on M2-3; leave main + PRs #12, #13, #14 untouched.
- Preserve 20Hz, deterministic RNG, M1 debug UI and source JSON; don't call M1 physical QA done.
- DoT shields before HP; no dead-unit effects/targeting.

## Review Focus
- Reapplying DoT must not postpone imminent next pulse.
- Freeze at exact expiry must not leak into next action.
- Same-target expired/immune DoT must not trigger phantom damage.
- Multiple statuses in differing insertion order must execute DOT before regen.
- Cleanse/remove TAUNT must remove the M2-2 targeting override and be immutable to input JSON.

### Task 1: Introduce failing status lifecycle tests
- [ ] Create `tests/m2_status_effects_test.gd`: periodic dot, stack cap, refresh, freeze/gauge, slow, defense, immunity and cleanse, regen, skill integration and 1x/3x replay.
- [ ] Run new CI step and inspect expected RED against M2-3.
- [ ] Create `scripts/combat/status_effects.gd` with typed categories / applied durations and pure pulse API; add battle public hooks; verify GREEN.

### Task 2: Integrate M2-3 skill effects
- [ ] Add status application for Aria, Serena, Elin, Luna, Bell, Leon; freeze RNG 30% and shield/taunt interaction.
- [ ] Replace legacy deferred markers with actual status events; update former M2-3 expectations without weakening skill behavior assertions.
- [ ] Re-run M2-1/2/3/4; fix parse/behavior regressions.

### Task 3: End-to-end QA and Draft PR
- [ ] Review core files and job logs for warnings, ensure all four suite markers and static validators.
- [ ] Update QA report/README/roadmap and create draft PR stacked on M2-3.
- [ ] Confirm actual final-HEAD CI, Windows/Android packaging status; leave physical gates pending.
