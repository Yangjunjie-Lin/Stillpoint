# Architecture (Godot 0.4.2)

Stillpoint’s supported runtime is **Godot 4.7** with the **Compatibility** renderer (`gl_compatibility`). Scene / Node / Resource ownership replaces the archived Tkinter loop.

## Autoloads

| Autoload | Responsibility |
| --- | --- |
| `EventBus` | Cross-system signals only |
| `GameManager` | Run metadata, `start_new_run` / `continue_run`, `ResourceRegistry`, resumable-run checks |
| `SceneRouter` | Swap `Main/CurrentScene` |
| `SaveService` | JSON under `user://`, atomic writes, migration, validation, settings → audio buses |
| `AudioManager` | SFX pool + music player (headless-safe no-op play) |

Actors, bullets, and levels are **not** autoloads. Autoloads must not become God Objects for combat state.

## Save validation pipeline

1. Read JSON from `user://run_save.json`
2. `migrate_payload()` — deep copy, version steps v0→v1→v2 (reject version &lt; 0 or &gt; `SAVE_VERSION`)
3. `validate_run_payload()` → `SaveValidationResult` (required fields, finite numbers, alive player health)
4. `inspect_run()` — game over / expiry checks → `RunSaveSummary`
5. `GameManager.inspect_resumable_run()` — additionally requires `level_id` exists in `ResourceRegistry`

**Future save policy:** version &gt; `SAVE_VERSION` → `future_version`, Continue disabled, no auto-downgrade, no overwrite.

## Continue vs New Game

- **Continue** — `GameManager.continue_run()` sets `player_name` from the save summary (menu `LineEdit` ignored). Never clears the run file.
- **New Game** — uses menu name; confirms before `SaveService.clear_run()`.

## Multi-level restore

`GameplayController._ready()` loads restore data first, then `_resolve_level_definition()` picks `LevelDefinition` from saved `level_id` via registry before world bounds, visuals, and camera are built.

Unknown `level_id` → `inspect_resumable_run()` invalid (`unknown_level`); do not silently fall back to prototype during Continue.

## Enemy / pickup saveability

`queue_free()` is deferred to end-of-frame. Autosave must skip:

- `is_queued_for_deletion()`
- dead enemies (`health.is_dead()`, `_reward_granted`)
- pickups without `definition_id`

`EnemyController.is_saveable()` / `PickupItem.is_saveable()` centralize this. `_active_enemy_count()` drives spawn targets (not raw child count).

Restore skips legacy dead enemy entries and `queue_free()` any enemy that fails `is_saveable()` after `from_dict()`.

## MovementComponent

Returns **world velocity in pixels per second**. Callers must **not** rescale the result. Speed buffs use `speed_multiplier` only.

## Weapons: definition vs runtime

`WeaponDefinition` is static; `WeaponRuntimeStats` is built per shot. Buff re-pickup uses **RESET_DURATION**.

## Camera resize

`CameraLimits.calculate_camera_limits(world_size, viewport_size)` is pure math. `GameplayController` listens to `Viewport.size_changed` and reapplies limits (safe to call repeatedly).

## Saves

| Kind | Path | Notes |
| --- | --- | --- |
| Run | `user://run_save.json` | `SAVE_VERSION = 2` |
| Settings | `user://settings.json` | Master / Music / SFX |
| Leaderboard | `user://leaderboard.json` | Profile-ish |

**Restored:** player, enemies, pickups, timers, difficulty, `level_id`, buff remaining times.

**Not saved:** projectiles.

Atomic write: `.tmp` → `.bak` → promote; restore `.bak` on replace failure (`_rename_absolute` hook for tests).

## Health restore

`HealthComponent.from_dict()` clamps max ≥ 1, current ∈ [0, max], defense ≥ 0. Non-finite values become safe defaults. Dead enemies are not spawned from saves.

## Extension points (not in 0.4.2)

Story chapters, bosses, equipment/skills, obstacle-aware spawn queries.

## Pause

`get_tree().paused` freezes gameplay nodes using default process modes. Combat clocks (`player.game_time`, buff expiry via `update_clock`) only advance in `_physics_process` while unpaused.
