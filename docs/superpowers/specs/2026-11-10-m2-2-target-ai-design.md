# M2-2 Target AI Design (provisional)
Date: 2026-11-10. Based on GDD and M2-1 contract; M2-1 is unmerged and M1 physical gate remains open.

## Goal
Add predictable role-aware basic-attack target AI to the existing fixed-step combat, including explicit frontline/backline, threat and a timed taunt override. No status effects or active skills in M2-2.

## Alternatives considered
- Keep every target rule in `auto_battle_core.gd`: easiest initially, grows coupled to damage and future skill actions.
- **Chosen: pure `target_selector.gd` with battle-owned runtime threat/taunt**: easy to validate headlessly, no RNG use, leaves future skills free to apply threat and taunts.
- Full behavior-tree/utility-AI package: flexibility not justified for 8-char prototype; unnecessary dependencies.

## Rules
1. Runtime unit fields: `row` (FRONT/BACK), `threat` (nonnegative integer), `taunt_until_tick` (exclusive tick).
2. Row is explicit when valid; otherwise infer from TANK/WARRIOR/MELEE/DEFENDER as FRONT, MAGE/ARCHER/RANGED/SUPPORT/ASSASSIN as BACK, or positional slot fallback. Roster legality and 2+3 lineup validation come later.
3. Role base threat: TANK/DEFENDER 100, WARRIOR/MELEE 40, other roles 10. After attacking, actor accrues threat equal to HP actually removed from the target (overkill excluded), capped to 1,000,000; `add_threat(team, id, amount)` provides a future skill hook.
4. A live taunter overrides role, row and threat until tick `now >= taunt_until_tick`. `apply_taunt(team, id, duration_ticks)` replaces any current taunt on that same team. Dead, missing, invalid/expired sources cannot force targeting. Hooks return bool for accepted input.
5. ASSASSIN targets BACK first, then the lowest current HP (stable tie by slot). MAGE/ARCHER/RANGED target FRONT first and lowest current HP. TANK/DEFENDER/WARRIOR/MELEE/SUPPORT and unknown roles target FRONT first and highest threat. If the desired row is empty, use surviving enemies on the other row.
6. No random rolls during target choice; ties are stable by original encounter order. The existing damage RNG remains unchanged. Dead units cannot be targeted.
7. Existing M2-1 default 'defender before other enemies' must remain valid for the original enemy data, which lists DEFENDER in array slot 2.
8. No change to `battle_sandbox.gd`, saved data, or the UI. Do not claim that the character skills or taunt-status implementation are done; this is a targeting hook.

## Acceptance tests
Role target fixtures; explicit row override; fallback after front dies; taunt overrides and expires at exact tick; invalid taunt rejected without clearing a good one; threat increase alters opponent priorities; source dictionaries immutable; speed/seed reproducibility and prior M2-1/M1 checks; Android/Windows CI retained.

## Non-goals / risks
Area targeting, heals, skill cooldowns, crowd-control stacking, formation editing and physical hardware QA not covered; M2-3/4/5 remain pending.