# M3-5 Superpowers Test-first Implementation Plan (2026-11-12)

1. Review M1 save_manager.gd and save_process_test.gd, M3-1..4 stat/ledger/checkpoint APIs, GitHub workflows. Consult official Godot 4.7 FileAccess.flush and DirAccess.rename_absolute/copy_absolute APIs.
2. RED: add comprehensive disk-based tests for growth/gear/economy/checkpoint serialization, stale revision, corrupted file/checksum, verified backup, v1 migration and three independent processes with no duplicate idle claim.
3. GREEN: profile_store.gd with explicit schema, validation, user:// safe path, checksum-protected envelope, verified temp write and backup rename, prioritized recovery, revision CAS; use M3-3/M3-4 logic without changing their balance.
4. Add Windows native tests using Godot 4.7.2 console runtime, validate Windows overwrite semantics, preserve M1 debug save and Android export. Review full M3/ M2/M1 CI and correct any failures.
5. Document incomplete UI/OS lifecycle integration, no offline server time authority, no real power-loss/fync durability guarantees. Create Draft PR targeting M3-4; do not merge to main or clear issue #2 until actual device QA.
