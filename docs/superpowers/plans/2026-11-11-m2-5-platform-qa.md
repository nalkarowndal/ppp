# M2-5 Cross-Platform QA Plan — 2026-11-11

> **For agentic workers:** REQUIRED SUB-SKILL: use superpowers:executing-plans and test-driven-development; prove RED before implementation and GREEN after.

**Goal:** Validate M2-5 on Windows-native engine/embedded EXE and Android emulator with real touch while retaining truthful real-device gates.
**Architecture:** Isolated QA telemetry in two UI scripts, emulator-only ADB journey, Windows native/headless EXE test, immutable M1 QA baseline.
**Tech Stack:** Godot 4.7.2 GDScript, PowerShell 7, Android adb/SDK35, GitHub Actions ubuntu/windows, Python screenshot validation.
**Spec:** `docs/superpowers/specs/2026-11-11-m2-5-platform-qa.md`

## Global constraints
- Stacked branch `feature/m2-5-platform-qa` / base `feature/m2-5-battle-ui`, no main merge.
- Existing M1 STEP/RESET/SAVE user data/CI and real-phone protection unchanged.
- Never claim physical-device PASS from hosted virtual runner/emulator.

### Task 1 Android emulator RED/GREEN
- [x] Create `scripts/qa/android_emulator_m2_battle.sh` with emulator-only x86 guard, logs/PNG, ADB touch journey.
- [x] Temporarily enable M1 Android emulator workflow on platform-QA feature branch, include real M1+M2 tests.
- [ ] Observe CI RED on missing M2_5_QA_TARGET instrumentation.
- [ ] Implement geometry/action telemetry and retry M1 + M2 ADB workflow until it passes.
- [ ] Download PNG, visually inspect and document simulator vs physical limitations.

### Task 2 Windows native + EXE
- [x] Add M2-5 scene integration test to existing Windows-native job.
- [ ] Add exported EXE debug-only M2 navigation/action QA and job validation.
- [ ] Confirm downloaded embedded EXE works on windows-latest host and log markers, without GUI claims.

### Task 3 final evidence
- [ ] Check M1/M2 suite, Windows native/EXE, Android emulator, ARM64 APK & static CI from exact final head.
- [ ] Document remaining physical mouse, real phone touch, DPI/notch, Korean glyph & save lifecycle.
- [ ] Create Draft PR and add evidence-only comment to M1 issue #2; leave issue open.
