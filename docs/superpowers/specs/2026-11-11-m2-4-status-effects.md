# Astral Chronicle M2-4 Status Effects — Design (2026-11-11)

## Goal and current state
The stacked M2-3 core executes 16 skill definitions and marks BURN/POISON/SLOW/FREEZE_30/DEF_DOWN/HEAL_REGEN (and Bell DEF_UP) as deferred. M2-4 turns these into real deterministic effects while keeping M2-1/2/3, old saves, debug UI and JSON base values intact. M2-1/2/3 Draft PRs #12/#13/#14 remain unmerged.

## Architectural choice
Use a pure GDScript `status_effects.gd` policy module for application, refresh/stacking, immunity, expiration and periodic pulse descriptions; `auto_battle_core.gd` integrates those descriptions into battle HP/shield/AI and emits events. No Godot Timer or global RNG, so 20Hz simulation and 1x/2x/3x replay remain deterministic.

## Provisional balance (specific values introduced in M2-4, tuning remains pending)
| Effect | Applied by skill | Duration | Stack/potency | Resolution |
|---|---|---|---|---|
| BURN | Aria ACTIVE | 4s | 3 stacks, 2% max HP per stack/s | DOT damage, subject to shield |
| POISON | Elin ACTIVE | 6s | 3 stacks, 1% max HP per stack/s | DOT damage, subject to shield |
| SLOW | Serena ACTIVE | 4s | refresh, SPD gauge gain -25% | action gauge only; base SPD retained |
| FREEZE | Serena ULTIMATE | 2s | 30% independent chance per living hit | no gauge gain, no actions |
| DEF_DOWN | Elin ULTIMATE | 6s | refresh, effective DEF -20% | damage calculations only |
| DEF_UP | Bell ACTIVE | 4s | refresh, effective DEF +10% | separate from existing temporary taunt |
| REGEN | Luna ULTIMATE | 5s | refresh, 3% max HP/s | heal (capped to max HP) |
| TAUNT | Bell ACTIVE / Leon ULTIMATE | 3s | refresh; one active taunter/team | M2-2 targeting override, removable |

- All durations count fixed simulation ticks (20 per sec). `expires_tick` is exclusive for control/stat modifiers; periodic pulses on exactly an expiry tick are included, then removed.
- BURN/POISON: shared status per (unit, type), max 3 stacks; re-application increases stacks and refreshes expiry, **does not delay already scheduled next one-second pulse**. Other types refresh duration and use latest/max applicable potency, not unbounded stack.
- If immune, application returns false and does not consume an additional status RNG roll. Initial immunity array comes from copied unit source `immunities`; the `set_status_immunity` hook can toggle at runtime.
- Public APIs: `add_status(team,id,effect,duration_ticks,potency=0.0)`, `remove_status(team,id,effect_or_category="ALL")`, `set_status_immunity(team,id,effect,enabled)` for later skill/boss implementation. `remove_status` returns number of distinct entries cleared; `DEBUFF` clears BURN/POISON/SLOW/FREEZE/DEF_DOWN; `BUFF` clears REGEN/DEF_UP/TAUNT. Explicit TAUNT removal also resets the targeting override.
- Each 20 Hz tick: advance statuses (apply periodic damage before healing; remove expired entries), check victory/defeat, then build readiness gauges using effective slow/freeze, and act. Dead units never produce pulses or act. Freeze at time zero of duration 3 prevents actions ticks 1 and 2; on tick 3 resumes.
- A skill `skill_cast` event now has `effect_type` and no deferred tag. Per-target `status_applied`, `status_immune`, `status_tick`, `status_expired` or `status_removed` events expose actual behavior. Cast events retain fixed history cap 64.
- Immunity prevents status application but not immediate skill damage. Damage/crit variance remain seeded; the same `RandomNumberGenerator` is used for Serena's 30% freeze after damage, only when target survives.
- Enemy targeting, threat, manual ultimates, cooldowns, base stats, JSON originals and M1 UI are unchanged. Script labels `data/skills.json` still `spec_only_not_implemented` until the broader phase is formally validated (passives/art/balance not included).

## Non-goals
New passives, dispel skills, elemental resistance stat, partial CC resistance formula, control diminishing returns, complete economy balance, status VFX/UI, offline combat simulation, physical Windows/Android QA. M2-5 will wire UI, animation and device QA.
