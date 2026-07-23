# Save v4 Guide

## Layout

```
user://saves/slot_01/
├── manifest.json
├── player.json
├── global_world.json
├── relationships.json
├── quests.json
├── world_flags.json
├── companions.json
└── regions/
    ├── base_town.json
    ├── base_wilderness.json
    └── base_dungeon.json
```

`manifest.region_chunks` maps real region IDs to filenames (for example `"base:town" → "base_town.json"`). Filenames are produced by `RegionIdUtil.to_chunk_filename()`; never reconstruct region IDs by string guessing in save code.

## Main Menu / Continue

`SaveSlotService` (autoload) queries the filesystem without a live `WorldSession`:

- `has_adventure_save()`
- `inspect_adventure_summary()` — player name, region, day/time, or `future_version` / `corrupt_manifest`
- `clear_adventure_save()`

`GameManager.has_resumable_adventure()` / `continue_adventure()` / `start_new_adventure()` use `SaveSlotService` only. Main Menu Continue prefers Save v4 Adventure, then falls back to Legacy Survival.

## Dirty Tracking

- Player / inventory / relationships / quests / flags / companions mark named sections dirty.
- Entity changes mark their region dirty via `WorldEntityRepository`.
- Leaving a region emits `region_chunk_captured` and marks the previous region dirty.
- Autosave may always refresh `manifest` / `global_world` / `player`, but only dirty regions are rewritten.
- Each successful section/region write clears only that dirty bit.

## Player Position

Continue restores the exact saved player transform after the region loads (`RegionTransitionContext.restore_saved_transform`). Portal transitions still use the target spawn marker.

## Discovered Regions

`WorldSession.capture_global_world_data()` / `restore_global_world_data()` round-trip `discovered_regions` and world time counters (`id_counters`).

## Corruption Recovery

- Invalid / missing `player.json` → slot rejected (try `.bak` first).
- Corrupt region chunk → try `.bak`; if still bad, warn and use region defaults; other regions continue.
- Corrupt entity snapshot entry → skip that entity and log its persistent ID.
- Manifest corruption → try `.bak`.

## Migration from v3

On Continue, if `user://world_save.json` exists it is migrated to `user://saves/slot_01/` and renamed to `world_save_v3_imported.bak`. A second Continue does not migrate again.

## Deferred

`SaveSectionProvider` is reserved for 0.8.0 modular providers. Save v4 currently uses coordinator section writers.
