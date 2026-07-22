# Save v4 Guide

## Layout

See `docs/WORLD_ARCHITECTURE.md` for the directory structure.

## Dirty Tracking

Only dirty sections are written on autosave. Region chunks are independent. Leaving a region forces that chunk to save.

## Corruption Recovery

- Invalid `player.json` → slot rejected
- Corrupt region chunk → region resets to defaults; other regions load
- Corrupt entity entry → entity skipped with warning

## Migration from v3

On Continue, if `user://world_save.json` exists it is migrated to `user://saves/slot_01/` and the original file is renamed to `world_save_v3_imported.bak`.
