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
- `validate_adventure_save()` — one authoritative validation result
- `inspect_adventure_summary()` — delegates to validation and adds safe summary defaults
- `clear_adventure_save()`

Validation parses `manifest.json` (then `.bak` for corruption), requires a legal non-future `save_version`, non-empty `current_region_id`, and Dictionary `region_chunks`. It parses `player.json` (then `.bak`) and requires Dictionary `player` and `inventory` sections. `global_world.json` may fall back to its backup or warned defaults. Results always include `valid`, `reason`, `warnings`, `used_player_backup`, and `used_manifest_backup`; summary name/date/time fields use safe defaults.

Main Menu distinguishes `missing`, `future_version`, `corrupt_manifest`, `missing_player`, and `corrupt_player`. A valid backup enables Continue and displays “Save recovered from backup”. A corrupt Adventure slot disables Adventure Continue and does not fall through to Legacy Survival; Legacy Survival is considered only when no Adventure slot exists.

## Dirty Tracking

- Player / inventory / relationships / quests / flags / companions mark named sections dirty.
- Entity changes mark their region dirty via `WorldEntityRepository`.
- Leaving a region emits `region_chunk_captured` and marks the previous region dirty.
- Autosave may always refresh `manifest` / `global_world` / `player`, but only dirty regions are rewritten.
- Each successful section/region write clears only that dirty bit.
- The manifest is the final commit. A failed manifest replace makes the save call fail, leaves a retry marker, restores the prior file, and removes the temporary file.

## Player Position

Continue restores the exact saved player transform after the region loads (`RegionTransitionContext.restore_saved_transform`). Portal transitions still use the target spawn marker.

## Discovered Regions

`WorldSession.capture_global_world_data()` / `restore_global_world_data()` round-trip `discovered_regions` and world time counters (`id_counters`).

## Corruption Recovery

Restore consumes the exact manifest/player primary-or-backup source selected by structural validation; a parseable but structurally invalid primary cannot override its validated backup.

- Invalid / missing `player.json` → try `.bak`; reject the slot as `missing_player` or `corrupt_player` if neither is usable.
- Corrupt region chunk → try `.bak`; if still bad, warn and use region defaults; other regions continue.
- Corrupt entity snapshot entry → skip that entity and log its persistent ID.
- Manifest corruption → try `.bak`.
- Missing/corrupt global-world primary and backup → continue with safe defaults and a warning.

`WorldSession` checks the boolean returned by `restore_session()`. Failure clears `resume_requested`, disables player input and autosave, prevents further session saves, unloads any partial region, emits `restore_failed(reason)`, and routes to the menu. It never creates a replacement default save or overwrites the damaged source.

## Migration from v3

On Continue, if `user://world_save.json` exists it is migrated to `user://saves/slot_01/` and renamed to `world_save_v3_imported.bak`. Legacy NPC data becomes `components.character` with nested health/state fields (including `is_downed` and `is_permanently_dead`); Chest and Pickup data become `components.chest` and `components.pickup`. A second Continue does not migrate again.

## Deferred

`SaveSectionProvider` is reserved for 0.8.0 modular providers. Save v4 currently uses coordinator section writers.
