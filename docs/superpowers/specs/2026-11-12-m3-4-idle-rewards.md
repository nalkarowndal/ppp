# M3-4 Offline Idle Earnings Specification (2026-11-12)

Base M3-3 Draft PR #20 on feature/m3-3-economy-inventory-ledger. Head feature/m3-4-offline-idle-rewards.

Goal: Pure, deterministic eight-hour offline currency rewards for 1..40 stages. No UI, battle rewards, loot drops or persistent storage.

State: versioned checkpoint with schema_version:1, last_exit_unix integer, stage integer. On actual logout, record trusted exit timestamp and highest legitimately cleared stage. On app resume use elapsed UTC seconds, clamped once to 28,800 seconds, then floor elapsed hours times floored hourly stage yield times 0.8. XP/hour floor(240 * 1.12^(s-1)); Gold/hour floor(200 * 1.12^(s-1)).

M3-3 integration: a successful claim calls Economy.try_claim with stable event_id offline:<last_exit_unix>, awarding XP crystals and gold only. Changing now_unix on replay does not change receipt ID; stale checkpoint + updated economy state is rejected. Advance last_exit_unix only after successful claim. Zero reward and failures preserve all inputs; preview remains side-effect free.

Fixtures: stage1 1h = 192 XP/160 gold; 8h = 1536 XP/1280 gold; 9h+ = 8h cap. Stage2 1h = 214 XP/179 gold. Reject backward clock, invalid balance and stage, corrupted/overflow states, duplicate receipts. Normalize checkpoint after JSON roundtrip.

Trust: local wall clock may be changed; no server validation, anti-cheat guarantees, stage-win authority or durable atomic save until later milestones. M3-5 persists checkpoint and ledger together; M3-6 provides UI. Draft only, no main merge or claim of M3 full approval.
