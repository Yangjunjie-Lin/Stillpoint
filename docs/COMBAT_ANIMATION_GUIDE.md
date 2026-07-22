# Combat Animation Guide (Stillpoint 0.6.0)

Placeholder animations ship with the project. Replace clips without changing gameplay code.

## Naming

| Clip | Purpose |
| --- | --- |
| `idle`, `walk`, `run` | Locomotion |
| `crouch_idle`, `crouch_walk` | Crouch |
| `jump_start`, `jump_loop`, `fall`, `land` | Airborne |
| `guard_enter`, `guard_loop`, `guard_exit`, `guard_break` | Guard |
| `attack_light_1` … `attack_light_3` | Melee combo |
| `hit_*_light`, `hit_heavy` | Hit reactions |
| `downed`, `get_up`, `death` | Incapacitation |

## Import rules

- Skeleton scale = 1; no non-uniform scale on skeleton parents.
- Loop only locomotion clips; attacks are one-shot.
- Root motion bone name: `root` (configurable later via bone map).
- Weapon socket: `WeaponSocket` under `CombatPivot`.
- Method tracks must call `CombatAnimationController` events:
  - `attack_started`, `attack_window_open`, `attack_window_close`
  - `combo_window_open`, `combo_window_close`, `attack_finished`

## Runtime wiring

- `CombatAnimationController` owns AnimationPlayer/AnimationTree parameter paths.
- `CombatComponent` opens/closes hitboxes from animation events only (timers are watchdog fallback).
- `AttackDefinition.animation_name` selects the clip; combo chain uses `next_combo_attack_ids`.

## Placeholder status

Current rigs are box meshes with procedurally generated `combat` AnimationLibrary clips. They demonstrate timing and events but are **not** production art.
