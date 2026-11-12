# M3-4 Test-first Implementation Plan (2026-11-12)

1. Review M3-3 economy transaction contracts, M3 roadmap and existing balance_config. Consult official Godot 4.7 Time API and document wall-clock tampering caveat.
2. RED: add tests for stage/hour golden vectors, tiny intervals, eight-hour cap, rollback, JSON normalization, duplicate receipts even when end time differs, and currency limit errors.
3. GREEN: add pure offline_rewards.gd with new_checkpoint, normalize_checkpoint, preview and try_claim; use the M3-3 economy receipt ID based exclusively on the initial saved exit time.
4. Extend M3 GitHub Actions; update Python balance config assertions. Confirm final-HEAD Godot/M3-1~4 regression and inherited M2/M1 workflows. Record failing/green test evidence.
5. Submit a new Draft PR targeting M3-3. Save and resume integration is M3-5, visual inventory and reward claim UI is M3-6. M1 physical device QA issue #2 remains open, main unchanged.
