# M4 10 Stage Vertical Slice – Design Spec (2026-11-12)

## Intent
Join Astral Chronicle M2 20Hz deterministic auto-battle and M3 level/equipment/economy/offline-profile architecture into a *playable, persistent first-ten-stage* loop without silently merging unfinished M1–M3 draft work. Primary player path: stage selection → battle → victory receipt → gold/XP/equipment → M3 growth → next challenge/restart.

## Constraints and approach
- Godot 4.7.2-stable, GDScript; Android ARM64/Windows development exports; portrait 360×800 and 480×960.
- Reuse existing M2 battle, M3 profile, economy, gear, growth. Isolate all new code in M4 stage runtime/scene; keep M1 debug button geometry and M2/M3 screens unmodified.
- Stage 1 initially open. Stage N+1 authorized only by persistent first-clear receipt N, not by M3 profile's provisional highest-stage default of 1.
- Player party 3–5 unique known heroes, currently a fixed UI party of first 3. Stage enemies from authored ten JSON entries, unimplemented full 40 stages and bosses excluded.
- Victory must be observed inside the M2 battle object; no UI button or arbitrary JSON field can directly pay. Transaction id unique, M3 revision compare-and-swap and checksum-backed save before displaying success. First-clear item reward only once; replay grants only currencies.
- Stage runs never modify M3's OS background timer rules or M1 debug save. M3 foreground overcredit (issue #25) remains a production blocker.
- UI retains existing dark navy/pale gold colors, Korean system font fallback, 48px+ touch targets, mobile safe area; actual art/animations and full 12-screen UX deferred to M5/M7.

## Alternatives and choice
1. Standalone M4 StageRunner using existing battle/economy/profile APIs (**selected**): smallest regression surface and deterministic, testable seams; new feature needs own scene and checks.
2. Refactor M2 battle preview into campaign + rewards: lower UI duplication, but high risk to existing M2 preview QA and main test geometry.
3. New independent progression/save format: quick prototype but breaks M3 ledger invariants and increases double-claim risk, rejected.

## QA and approval
Headless stage 1–10 victory, invalid/duplicate parties, locked stage, M3 growth+equipment into battle, first-time item, replay, concurrent stale save, disk reload; native scene UI button contract; 360×800/480×960 rendered PNG; M1–M3 regression and Windows/Android builds. Passing CI is **not** Windows/Android physical acceptance. Main merge and M4 approval require physical QA, bug #25 resolution, final review and all exit gates.
