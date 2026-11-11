# Astral Chronicle M2-5 Windows / Android QA Design — 2026-11-11

## Baseline
M2-5 Draft PR #16 (branch `feature/m2-5-battle-ui`) implements a playable 3v3 Godot Control scene but does not prove real Windows GUI clicks or Android arm64 physical-device behavior. Existing M1 native Windows, embedded Windows export, arm64 debug APK export and Android x86_64 emulator QA are independent. The M1 emulator workflow currently triggers only on main and only taps M1 step/reset/save, then tests persistence.

## Scope and evidence tiers
1. **Tier A — CI Windows native engine:** Godot 4.7.2 Windows runner loads M2 scene, executes deterministic UI signals, event log and M1 regression. Can prove Windows platform runtime but **not** real unlocked desktop pointer/display.
2. **Tier B — CI Windows exported EXE:** execute downloaded embedded EXE in a *new process* in headless debug QA mode, navigate from the real M1 scene to M2, test AUTO, speed, restart and return. Can prove exported binary and resource packaging; **not** physical mouse or Windows screenshot.
3. **Tier C — CI Android x86_64 emulator:** boot AVD, install debug APK, complete existing M1 ADB touch/save test, then navigate M2 using **actual adb shell input tap/swipe**, taking PNG of M1, battle start, controls and return. Validate app process, button geometry, UI event log and package ABI. Is **not** physical arm64 hardware.
4. **Tier D — CI Android ARM64 APK export:** official signed debug artifact, v2/v3 signature and embedded arm64-v8a. Build evidence only.
5. **Tier E — real Windows PC + real Android arm64 phone:** locked/unlocked desktop, physical mouse+screenshots, phone touch, density/notch/safe-area, OS lifecycle, Hangul are pending. Need authorized local hardware and collected PNG/logs; cannot be inferred from A-D.

## Implementation and safety
- New branch `feature/m2-5-platform-qa` stacked on Draft PR #16; create independent Draft PR, do not merge main or close M1 issue #2.
- Add debug-only M2 geometry telemetry to M1 launcher + M2 combat scene. Coordinates use `get_viewport().get_screen_transform() * get_global_transform_with_canvas() * (size/2)` (actual canvas-to-pixel mapping). Report `visible` with ScrollContainer clipping; headless/motion layout may differ from physical devices.
- `M2_5_QA_TARGET` records supported M2 buttons and `M2_5_QA_ACTION` logs state transitions, only in debug exports, no personal information and no user files. Do not weaken M1 QA identifiers or saved state.
- Android script performs destructive `adb input` **only on `ro.kernel.qemu=1` and x86*** device inside emulator-only CI, never on connected physical device. Does not clear package data on M2 phase (preserve verified M1 saved turn).
- Test script RED first: against uninstrumented M2-5 UI, test must fail missing `M2_5_QA_TARGET ENTER`; only then implement runtime hooks.
- Exported EXE command-line test uses exactly one custom debug flag `--m2-windows-qa`; no future runtime save effects.
- Avoid treating Android accessibility hierarchy (Godot renders into one native surface) as sufficient for game buttons. ADB taps follow *current* Godot-reported pixel positions, not static estimated taps.
- Artifact screenshot review: simulator screenshots must be manually inspected for Hangul glyphs, clipping, hit areas and safe area. QA only complete at the tier with direct evidence.
- Existing M1 scripts stay unmodified, except CI orchestrator and new isolated M2 script.
