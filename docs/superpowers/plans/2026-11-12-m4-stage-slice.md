# M4 Stage/Reward/Save Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver a repeatable ten-stage combat-to-reward-to-growth loop with permanent receipts and portable portrait UI.

**Architecture:** Isolate one M4 orchestrator from M2 simulation and M3 profile/economy, then a native portrait Godot Control stage selector. Do not modify earlier stage processors or M3 offline lifecycle.

**Tech Stack:** Godot 4.7.2, GDScript, JSON, GitHub Actions, Linux Xvfb, Windows x64 and Android ARM64 debug export.

**Spec:** `docs/superpowers/specs/2026-11-12-m4-stage-slice.md`

## Global Constraints
- 8 existing characters, 10 authored stages, M2 20Hz determinism, M3 economy receipt and checksum profile are authoritative within the offline prototype.
- Save only after victory; no free grant via UI, no direct main merge or physical QA claims.
- Preserve M1 development/debug UI touch coordinates and earlier M2/M3 scenes.

## Review Focus
- Duplicate stage settlement: persisted receipt must block repeated first-clear grants.
- Two sessions at same profile revision: later stale save must be rejected without mutating disk.
- Invalid or duplicate party/unknown stage: no active battle or payout.
- Growth/equipment changed after prior battle: new stage should load fresh stats from saved profile.
- Physical Android background/no pause events: not validated by CI; issue #25 remains a blocker.

### Task 1: M4 battle/reward orchestrator
**Files:** `scripts/core/m4_stage_run.gd`, `tests/m4_stage_loop_test.gd`, `data/stages.json`
**Interface:** `initialize(profile_path) -> Dictionary`; `start_stage(stage:int,party_ids:Array)->Dictionary`; `advance_ticks(count:int)->Dictionary`; `settle_victory()->Dictionary`; `available_stages()->Array`.
- [x] Test-first: missing M4 orchestrator produces expected test failure (RED).
- [x] Integrate M2 Battle, M3 Growth/Gear, Economy receipt and Save CAS (GREEN).
- [x] Add tests for real stage1–10 victories, earning enough XP/gold to grow, equipped weapon stats, replay, session restart and concurrent CAS.
- [x] Commit and preserve isolated M4 branch.

### Task 2: Usable portrait scene and entry button
**Files:** `scenes/m4_stage.tscn`, `scripts/ui/m4_stage_ui.gd`, `scripts/ui/main_ui.gd`, `tests/m4_stage_ui_test.gd`
**Interface:** `current_stage()->int`, `advance_ticks(count:int)->Dictionary`; named `StageButton1`/2, `RewardResult`.
- [x] UI contract tests before scene existed (RED).
- [x] Implement 10 stage buttons and battle status/HP/speed, reward text, M3 growth button (GREEN).
- [x] Append M4 entry below M1/M2/M3 controls, preserving original QA geometry.

### Task 3: CI, visuals and documentation
**Files:** `.github/workflows/godot-m4-stage.yml`, `tests/m4_stage_visual_capture.gd`, `docs/qa/m4_stage_vertical_slice.md`, roadmap and README.
- [x] M4 Godot import, stage-loop + native UI integration script in official 4.7.2 runner.
- [x] Linux Xvfb stage screen captures for 360×800 and 480×960 with CJK fallback.
- [x] Regression workflows for M1–M3 and Windows/Android debug export.
- [ ] Obtain actual Windows unlocked-screen click/photo and physical Android arm64 touch/save/notch/Korean QA.
- [ ] Resolve M3 offline foreground-time overcount issue #25 and perform independent code review before final approval.
- [ ] Only after all gates, review and choose whether to merge stacked Draft PRs.
