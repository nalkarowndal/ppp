# M3-5 Profile Persistence Specification (2026-11-12)

Base M3-4 Draft #21. Implement isolated production-profile storage at user://astral_profile_v2.json without changing legacy M1 development save.

One versioned profile encapsulates M3-1 hero growth (keyed by known eight character IDs), M3-2 equipped gear and inventory ownership, M3-3 all six currencies and permanent event receipts, and M3-4 offline checkpoint and highest-cleared stage. Validate and normalize entire nested profile. Reject corrupted hero-level/star combinations, invalid references, spoofed receipts, mismatched gear owners and unsupported versions. JSON float values must normalize to ints before reuse.

Write a checksum envelope with SHA256 of raw serialized payload text (not a security MAC); write temp, flush, verify, rotate prior verified primary to a verified backup, rename temp to primary, then validate committed file. Load primary then backup; allow temp only if no primary/backup. Increment and compare revision as best-effort stale-write prevention. Fail closed when no valid save, do not auto-reset progress.

Migrate a defined, separate version-1 M3 profile shape by adding empty hero/loadout mappings while preserving economy receipts and checkpoint. Never auto-migrate or delete the M1 debug save file. Save offline reward and receipt+checkpoint as one serialized profile, and return success only after commit verification. Expose offline claim/logout APIs but do not wire UI/OS signals until M3-6.

Risks: no durable fsync-directory guarantee, cross-process locking, server authority, anti-cheat, Android ARM64 physical I/O validation, or complete OS suspend/crash survival. CI covers actual separate Godot processes on Linux/Windows, intentionally corrupted save JSON, backup recovery, and new/legacy profiles. Draft only, main and QA gate unchanged.
