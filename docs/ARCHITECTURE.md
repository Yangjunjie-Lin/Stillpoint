# Architecture (Godot)

Stillpoint’s supported runtime is Godot 4.7. Scene / Node / Resource ownership replaces the old Tkinter Canvas loop.

## Autoloads

| Autoload | Responsibility |
| --- | --- |
| `EventBus` | Cross-system signals only |
| `GameManager` | Run metadata, return-to-menu |
| `SceneRouter` | Swap `Main/CurrentScene` |
| `SaveService` | JSON under `user://`, atomic writes |
| `AudioManager` | Future SFX/music hooks |

Actors, bullets, and levels are **not** autoloads.

## Components

- `HealthComponent` — HP, invulnerability, death
- `ExperienceComponent` — **session combat level** / XP (not profile level)
- `WeaponComponent` — fires from `WeaponDefinition` without mutating shared resources in place
- `StatusEffectComponent` — timed buffs
- `MovementComponent` — WASD velocity helper
- `Hitbox` / `Hurtbox` — damage protocol via `DamageInfo`

## Data vs runtime

`EnemyDefinition` / `WeaponDefinition` / `LevelDefinition` are static `.tres` resources. Instance HP and cooldowns live on nodes/components.

## Extension points

- Story: `ChapterDefinition`, `DialogueDefinition`, `ObjectiveDefinition`, `EncounterDefinition`
- Enemies: new `.tres` + optional inherited enemy scenes / AI scripts
- Equipment / skills: add components beside `WeaponComponent`; keep UI on signals
- Profile progression: separate from `ExperienceComponent.level` (session combat level)

## Pause

`get_tree().paused` freezes gameplay nodes. Pause UI uses `PROCESS_MODE_WHEN_PAUSED`.
