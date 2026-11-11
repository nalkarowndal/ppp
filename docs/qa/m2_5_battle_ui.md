# Astral Chronicle M2-5 — Interactive Battle UI / Visual QA (2026-11-11)

**Branch:** `feature/m2-5-battle-ui` stacked on M2-4 `feature/m2-4-status-effects`. This is a development preview / Draft PR, not a signed-off production combat UI.

## Live feature scope
- Godot scene `scenes/battle_m2_5.tscn` driven by `scripts/ui/battle_ui.gd`, separate from the M1 startup scene.
- M1 screen `scripts/ui/main_ui.gd` has an optional **M2-5 전투 화면 열기** button deliberately inserted *after the M1 SAVE section*. Existing M1 STEP/RESET/SAVE button texts and sandbox-turn save logic remain unchanged.
- Real M2-1..4 `auto_battle_core.gd` 20Hz simulation, initial 3x heroes and 3x enemies loaded from JSON, seeded deterministic fight. **Preview enemies' HP is ×4** for testing ultimates; original `data/enemies.json` is not modified, no balancing approval.
- Layout: Korean title, battle status + elapsed clock, three ally/three enemy panels with row, names, HP bar & value, ally energy, status names/remaining seconds, per-ally ultimate CTA, recent events. Mobile-portrait 360×800 scalable Control/ScrollContainer with 48px minimum functional button heights.
- Speed 1x→2x→3x changes logical ticks advanced per frame. 20 Hz is authoritative; `_process` limits catch-up work to 16 logical ticks per draw and clamps delta; the remainder is retained.
- `궁극기 AUTO ON/OFF` affects **ultimate automation**, not basic/active actions. Manual ult buttons are disabled until the selected ally is alive, energy=100, AUTO OFF and battle running. Press queues via existing M2-3 `request_ultimate()`; next action executes.
- Restart resets combat seed, auto mode, rate and event cursor; return navigates to M1 preview launcher. Reduced motion toggle disables subsequent card flashes.
- Event-driven card tint + a 0.22s bound Tween provides **simple feedback** for hits/heals/skill casts; no final character sprite animations, cutscenes, sound, or VFX asset pipeline.
- `battle_view_model.gd` formats snapshots read-only. 64-entry core event history flows into a short UI combat log.
- No new persistence, rewards, stage progression, true party selection, official art or complete 12-screen design.

## Test-first evidence
- RED: [M2 CI #42982708112](https://github.com/nalkarowndal/ppp/actions/runs/42982708112) — M2-1..4 PASS and missing preview scene fails M2-5.
- First GREEN: [M2 CI #42983269785](https://github.com/nalkarowndal/ppp/actions/runs/42983269785) — real 3v3 scene + button/status/auto/manual speed/restart integration PASS.
- Event regression RED [#42983386835](https://github.com/nalkarowndal/ppp/actions/runs/42983386835) — re-render duplicated event-cursor feedback.
- Event regression GREEN [#42983484130](https://github.com/nalkarowndal/ppp/actions/runs/42983484130) — tick+ordinal cursor tracks new events correctly; bound Tweens die with cards.
- Real Linux/Xvfb 360×800 preview screenshot revealed **missing Hangul glyphs (□)** with default runner fonts. Installing `fonts-noto-cjk` in CI fixed the screenshot text; `SystemFont.has_char(한)` is checked in headless UI suite. [CJK-correct 360×800 and 480×960 CI #42984001365](https://github.com/nalkarowndal/ppp/actions/runs/42984001365) completed successfully and original PNGs were inspected.
- Expanded screenshot capture: initial, 70-tick combat state (status/damage feedback), scrolled controls on 360×800 and initial on 480×960. Verify newest branch HEAD run and inspect artifacts before claiming these phases visually approved.
- `tests/m2_battle_ui_test.gd` runs real scene node tree and UI pressed-signal handlers but **not** real Windows mouse or Android touch hardware.

## Visual evidence and caveats
- GitHub Actions `Godot M2 Combat Core` uploads `m2-5-rendered-ui-preview` PNG artifact and `m2-core-logs`. Open a successful run, click **Artifacts → m2-5-rendered-ui-preview** to review the captured 360×800 / 480×960 layouts.
- Linux Xvfb+software OpenGL capture proves the Godot renderer drew nonblank, multicolor images; screenshots were inspected for Korean glyphs and no obvious overlapping in first viewport. It is **not** a Windows GUI screenshot or Android screenshot.
- Screen is an M2-5 *technical preview*: panels are stylized placeholders rather than final anime/pixel-art characters; status icon/animation/iconography remains a later art and production validation gate.
- Controls and log below fold require vertical scroll at 360×800. The footer stays visible. Check portrait safe areas, accessibility, tap targets, content scales and notch/cutout on physical ARM64 Android.
- Godot currently uses a **SystemFont** preference list. The Linux Xvfb runner explicitly installs Noto Sans CJK; portable font bundling and cross-device Korean glyph certification remain pending. Do not treat CI font install as proof of end-device glyph availability.

## Reproduction
```bash
godot --headless --path . --import
godot --headless --path . --script res://tests/ui_integration_test.gd
godot --headless --path . --script res://tests/m2_combat_core_test.gd
godot --headless --path . --script res://tests/m2_target_ai_test.gd
godot --headless --path . --script res://tests/m2_skill_runtime_test.gd
godot --headless --path . --script res://tests/m2_status_effects_test.gd
godot --headless --path . --script res://tests/m2_battle_ui_test.gd
```

Run the project with Godot 4.7.2, then on the M1 scene scroll down to **M2-5 전투 화면 열기**. Use **궁극기 AUTO OFF**, await full energy, click a character's ultimate, switch 1×/2×/3×, inspect the status labels, press **재시작**, then **← 돌아가기**. Compare M1 STEP, RESET, and SAVE before/after opening the preview.

## Approval gates **not satisfied**
1. Direct Windows PC GUI mouse input and screenshots (M1 issue #2) not carried out. A Windows EXE build/test is not physical GUI QA.
2. Android arm64 physical touch, app resume, persistent save, safe area and Hangul readability not carried out. Debug APK export != hardware QA.
3. No final illustrations, pixel animation/VFX/audio, accessibility certification or full battle result/rewards. No production art sign-off.
4. No merge to `main`; upstream Draft PR #12/#13/#14/#15 and this M2-5 Draft PR remain staged. M2 milestone as a whole is **not approved**.
