# Stillpoint 0.7.1 Release Notes

Stillpoint 0.7.1 is a stability release focused on runtime persistence, test reliability, and resource cleanup. It adds no new gameplay systems and does not change the stable WorldSession, Region, Quest, Dialogue, ActorFactory, or Save v4 architecture.

## Fixes

- RelationshipService now normalizes JSON string keys to `StringName`, validates state dictionaries, clamps affinity/anger, rejects non-finite numbers, and safely handles legacy `player_affinity` data.
- Added real JSON roundtrip, string-key normalization, corrupt-state isolation, and Save v4 process-restart relationship tests.
- Replaced incomplete CharacterController test trees with a complete `CharacterTestFactory` fixture and attached transform/collision tests to the SceneTree before querying transforms.
- Test lifecycle cleanup now resets autoload state, clears test registry entries, settles deferred frames, and frees test-owned nodes and resources. The full suite exits with zero ObjectDB and Resource leaks.
- Added `tools/python/run_godot_tests.py`, which streams and archives the Godot log, validates the test summary, rejects unexpected fatal diagnostics, applies a precise expected-error allowlist, and enforces leak thresholds. CI now runs this wrapper and uploads the log artifact.

## Compatibility

- Save Schema remains v4 (`save_version = 4`). Existing 0.7.0 Save v4 data is directly compatible.
- v3 to v4 migration behavior is unchanged and covered by the existing migration suite.
