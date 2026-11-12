# M3-3 재화·인벤토리·중복 수령 방지 QA

Date 2026-11-12. Base M3-2 Draft PR #19. Godot 4.7.2; no changes to M1 debug save or M2 battle scenes.

## 기능
- 6 currency keys: gold, xp_crystals, ascension_stones, enhancement_stones, skill_books, crafting_materials.
- Single pure state: schema_version, wallet, inventory, seen_events, next_item_serial.
- Claim: caller-provided unique event ID + positive rewards + 0..N known equipment templates. Every equipment instance mints a monotonically increasing unique ID. Template duplicates mint distinct item instances.
- Spend: signed positive currency requirements, all-or-nothing debit and event receipt.
- M3-1/M3-2 adapters: try_level_up, try_ascend, try_enhance. Existing growth/equipment formula APIs remain unchanged; successful calls commit wallet/item updates with an idempotency receipt.
- Replay: duplicated event IDs reject both repeated and changed payloads, and the same ID cannot be used for a different operation.
- Deterministic validation: invalid currency, integer overflow, missing template, inventory capacity, serial collision and insufficient balance reject without any debit or receipt.
- JSON roundtrip normalize_state recognizes integral float values from Godot JSON.parse for wallet, serial and equipment enhancement level. It rejects malformed receipts or corrupted state.

## Constraints / security
- Max 2,000,000,000 units per currency; inventory cap 200; serial cap 1,999,999,999 (MVP prototype limits).
- Receipt history is **not pruned**: never remove claimed IDs to avoid granting the same reward again. M3-5 must persist state + receipts together atomically with backups/migrations.
- The unique event ID/reward payload comes from trusted game logic. No network/server authority or prevention of modified local saves at this phase. Do not advertise this as anti-cheat.
- No rewards from actual stage victories yet; real stage clearance/victory rewards are M4 integration.
- No UI/graphics implementation here. Superdesign-based inventory UI remains M3-6 scope; physical Windows/Android ARM64 tests unapproved, issue #2 remains open.

## Automated QA
Godot 4.7.2 headless --import, tests/m3_growth_test.gd, tests/m3_equipment_test.gd, tests/m3_economy_inventory_test.gd, inherited M2-1..5 and M1.
Test claim, retry same/different payload, cross-operation transaction ID replay, grants to M3-2 equip, partial debit, ascension/level/gear enhancement wrappers, JSON reload, overflow/collision/corruption. Final CI results tracked on PR.
