# M2-3 Data-driven skill and ultimate runtime design (2026-11-11)

## Scope and inheritance
Branch `feature/m2-3-skill-runtime` is **stacked on M2-2 Draft PR #13**, which is stacked on M2-1 Draft PR #12. Neither parent PR is in `main`. Build Godot 4.7.2 fixed-step combat feature without touching M1 UI, debug saves or battle sandbox.

## Decision
Prefer a small GDScript `skill_resolver.gd` for lookup/target-selection and cooldown decisions, with `auto_battle_core.gd` remaining owner of deterministic runtime mutations, RNG, health, shield, threat and events. Do not bring in an external Gameplay Ability System or change immutable design data fields prematurely.

## Runtime contract
- Load `data/skills.json` by ID using existing Repo.load_array; retain `status:spec_only_not_implemented` data metadata until M2-4 completes deferred secondary effects.
- Character `skill_ids` permit max one matching ACTIVE and ULTIMATE each. Unknown/malformed skill refs never cast. Synthetic/no-skill units preserve prior M2-1/2 combat behavior.
- `step_ticks`: when action gauge fires, select **auto ultimate if enabled, energy >=100, valid ultimate**; else **active if cooldown elapsed and useful**; else **basic**. Each gauge action yields one action, not two. Enemy units can cast if explicit skills are supplied.
- Starting energy defaults to 0, capped 0..100. The optional `energy` and `starting_hp` fixture inputs support wave carry-over / boundary QA only; ordinary JSON heroes start full HP and zero energy.
- Basic +10 energy, active +10 energy, ultimate consumes 100. No passive energy regeneration. Ultimate default auto enabled for both teams; `set_auto_ultimate(bool)` changes ally auto-use only. `cast_ultimate("ally", id)` immediately casts if running, ally alive, energy >=100 and ultimate valid, with no gauge consumption; never works for the enemy; doesn't expose a shortcut to generate energy.
- Active cooldown in exact 20 Hz integer ticks: `ceil(cooldown_sec*20)`, start at successful cast tick; next cast when `_ticks >= cooldown_until_tick`. Reset on setup; no cooldown for ultimate (energy gate).
- Targets: SINGLE_ENEMY, ENEMY_BACK (taunt first), UP_TO_3_ENEMIES (primary then stable roster order), ALL_ENEMIES, ALL_ALLIES, ALLY_LOW_HP (lowest remaining HP for heal; lowest HP percent for shield may be considered after M2), SELF. Invalid/no living targets cause skip without spending energy/cooldown.
- Effect primaries: DAMAGE/BURN/SLOW/POISON/FREEZE_30/DEF_DOWN apply immediate damage. MULTIHIT_3 produces 3 independent coefficient 0.65 hits on one target; CHAIN uses design coefficients 1.5/1.1/0.75 to up to three distinct enemies. HEAL / HEAL_REGEN heals `floor(ATK * coefficient)` up to missing HP. SHIELD adds `floor(MAX_HP*coefficient)` to each target, for Leon's active on one ally and Bell ultimate on all allies. TAUNT grants 3s targeting override (M2-2 policy), while DEF bonus deferred; TAUNT_SHIELD shields self and taunts for 3s. When shield exists, incoming damage depletes shield before HP. Overkill threat counts **actual HP loss**, preserving M2-2.
- Status policy: BURN, SLOW, POISON, FREEZE_30, DEF_DOWN, REGEN and DEF_BUFF are **M2-4 deferred**. M2-3 emits `status_deferred` events for these secondary effects, NOT a promise they were applied. No freeze RNG is rolled now. The actual status proc, durations, stacks, immunity, regen-over-time etc live in M2-4.
- Event stream remains capped at 64. Emit `skill_cast` (actor, skill, category, target_ids, manual flag), `skill_damage` (target, damage, shield_absorbed, hp_loss, critical), `skill_heal`, `skill_shield`, `status_deferred`. Existing `basic_attack` remains compatible and can gain optional shield fields.
- For target suppression rules, treat shield and heal effects as valid even when all full (shield builds before damage); AI active heals cast only if someone is injured. Auto ultimate heal is also skipped if everyone full; manual may spend energy intentionally. Keep RNG deterministic by using battle-owned `_rng` exclusively, no global random.
- No edits to actual skill descriptions/coefficients in `skills.json` until M2-4; chain hit coefficients are taken from existing `system_balance.md` design specification (150/110/75%). All 16 **primary** effects are exercised through real battle events.
- Manual ultimate input timing must be identical for replay. The caller is responsible for reproducing the same manual commands at the same logical tick.

## Acceptance
RED fail in new headless M2-3 test prior to code; GREEN on official 4.7.2 Godot M2 workflow after code; existing M2-1, M2-2 tests and M1 workflows do not regress. Check 16 real definitions, cooldown 8s/7.5s integer boundaries, 100-energy cap and spend, manual vs auto, target selection, heal/shield/taunt, 3-hit and chain, invalid commands, deterministic seed/speed/source JSON immutable, and event history.

## Non-goals
No full statuses, passives, PvP, UI input controls, scene animations, 5-unit UI formation editor, physical Android ARM64/Windows GUI QA, or merge to main. M1 #2 is still a blocking device gate.