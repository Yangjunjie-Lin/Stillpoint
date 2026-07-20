# Architecture (Godot 0.4.1)

Stillpoint’s supported runtime is **Godot 4.7** with the **Compatibility** renderer (`gl_compatibility`). Scene / Node / Resource ownership replaces the archived Tkinter loop.

## Autoloads

| Autoload | Responsibility |
| --- | --- |
| `EventBus` | Cross-system signals only |
| `GameManager` | Run metadata, `start_new_run` / `continue_run`, `ResourceRegistry` |
| `SceneRouter` | Swap `Main/CurrentScene` |
| `SaveService` | JSON under `user://`, atomic writes, migration, settings → audio buses |
| `AudioManager` | SFX pool + music player (headless-safe no-op play) |

Actors, bullets, and levels are **not** autoloads. Autoloads must not become God Objects for combat state.

## MovementComponent

Returns **world velocity in pixels per second**.

| Field | Role |
| --- | --- |
| `max_speed` | Cap (px/s) |
| `acceleration` | Toward target when input present |
| `deceleration` | Toward zero when input released |

Callers assign `velocity = movement.compute_velocity(...)` and must **not** multiply by speed again. Speed buffs use `speed_multiplier` only.

## Weapons: definition vs runtime

- `WeaponDefinition` — static `.tres`. Never mutated at runtime.
- `WeaponRuntimeStats` — built per shot from base definition + level modifiers + `StatusEffectComponent`.

Temporary buffs (`double`, `pierce`, `large`, `rapid_fire`) apply only inside `WeaponComponent.build_runtime_stats`. Re-picking the same buff uses **RESET_DURATION** (refresh from now; no stacking multipliers).

## Status effects

`StatusEffectComponent.RefreshPolicy`:

- `RESET_DURATION` (default) — re-pickup restarts the timer
- `EXTEND_DURATION` — adds time from the later of now / current end
- `KEEP_LONGEST` — keeps the farther end time

Combat timing uses **game clock** (`player.game_time`), not `Time.get_ticks_msec()`. Pause freezes that clock with the scene tree.

Signals: `effect_added`, `effect_refreshed`, `effect_removed`, `effects_changed`. HUD listens via `EventBus.player_status_changed`.

## Items

`ItemDefinition` resources live in `resources/items/`. `LevelDefinition.item_pool` + `ItemSelection.choose_weighted_item` drive spawns (weight, `minimum_level`). Colors / durations are not hardcoded in `GameplayController`.

## ResourceRegistry

`GameManager.registry` indexes Enemy / Item / Weapon / Level definitions by `id` at startup. Duplicate ids error. Saves store **ids**, not file paths or full static blobs.

## Camera and bounds

Camera2D limits follow `LevelDefinition.world_size` (with viewport-centering when the map is smaller than the view). Players and enemies clamp with collision-radius insets. Prototype level ships **Left / Right / Top / Bottom** static bodies.

## Saves

| Kind | Path | Notes |
| --- | --- | --- |
| Run | `user://run_save.json` | `SAVE_VERSION = 2`, migrate v0→v1→v2 |
| Settings | `user://settings.json` | Volumes applied to Master / Music / SFX |
| Leaderboard | `user://leaderboard.json` | Profile-ish, separate from run |

**Run restore covers:** player (HP, XP, score, position, status remaining), enemies (id, definition, HP, baked combat stats, position), pickups, autosave/item timers, difficulty.

**Not saved:** active projectiles (documented; cleared on restore).

Atomic write: `.tmp` → rename current to `.bak` → promote `.tmp` → delete `.bak` (restore `.bak` on failure).

`has_valid_run` / `inspect_run` reject missing, corrupt, expired, or `is_game_over` payloads. New Game clears only after menu confirm; Continue never clears.

## Profile vs run

Session combat level lives on `ExperienceComponent` for the current run. Future profile / meta progression must stay separate from that session level.

## Extension points (not in 0.4.1)

- Story chapters / dialogue / objectives (`ChapterDefinition`, etc. stubs)
- Boss encounters and multi-level routing
- Equipment and skill trees (compose beside `WeaponComponent`; keep UI read-only via signals)
- Obstacle-aware spawn queries (API reserved via spawn helpers)

## Pause

`get_tree().paused` freezes gameplay. Pause UI uses `PROCESS_MODE_WHEN_PAUSED`. Autosave runs on pause.
