# Action Camera and Combat Identity 0.10.0

## Audit

The accepted `develop` baseline (`61b6333`) had one `PlayerController3D`, one
`CombatComponent`, animation-event attack windows, `Hitbox3D`/`MeleeSweep3D`
damage delivery, a fixed-offset `CameraController3D`, and rebindable
`InputBindingService` actions. `AttackDefinition` already carried authored
poise, guard, parry, hitstun, blockstun, and knockback fields, but only guard
and the light combo were wired into runtime behavior.

## Existing behavior retained

- `PlayerController3D` remains the only living-world player entity.
- `CombatComponent` remains the only player/NPC damage pipeline.
- Animation method events own attack start, active hit window, combo window, and
  attack completion. Watchdog/fallback timelines remain only for missing clips.
- Save v4 remains canonical. Camera preferences live in `SaveService` settings;
  transient combat states are never serialized.
- CharacterBody3D remains simulation-authoritative for movement and attack
  displacement. Animation never writes actor world position.

## Modified behavior

- The fixed offset camera is now a yaw/pitch action rig with a SpringArm query,
  authored first-person anchor, runtime perspective switching, shoulder swap,
  FOV/sensitivity/inversion/smoothing settings, free-aim ray APIs, and UI-aware
  mouse capture.
- Exploration movement remains camera-relative. A valid lock changes facing to
  the target and left/right input becomes strafe/orbit movement.
- `CombatComponent.CombatState` now owns `PARRY_WINDOW`, `DODGING`, and
  `STAGGERED`, with explicit transition timing, blockstun/hitstun, and poise
  pressure. `CharacterState` continues to describe coarse actor availability.
- Guard button press opens a short parry window; missed timing follows normal
  blocking. Dodge uses authored energy, duration, distance, and iframe values.

## New behavior

- `TargetingComponent3D` filters living, loaded, same-region, in-range,
  view-cone, line-of-sight candidates and provides deterministic best-target,
  lock, cycle, unlock, invalidation, and aim-point APIs. Rebindable `[` and `]`
  inputs expose deterministic left/right cycling while preserving `R` as the
  explicit lock/unlock action.
- `PoiseComponent` supplies max/current poise, delayed regeneration, and a
  poise-break signal. Guarded hits apply reduced authored poise damage; a break
  enters stagger without overriding downed/death.
- `attack_heavy_1.tres` is a distinct authored attack resource. It consumes
  energy once and uses the same animation windows and hitbox/sweep route.
- Dodge invulnerability is a named `Hurtbox3D` source (`dodge`) and is revoked
  at the authored iframe end. First-person presentation hides the near-body
  visual root only; it owns no gameplay state.
- HUD lock text and first-person center reticle provide minimal combat feedback.

## Camera switching safety

Switching is rejected while the player is downed or permanently dead. Otherwise
it changes only presentation/control context: position, velocity, health,
energy, equipment, inventory, identity, region, and legitimate target state are
untouched. Modal UI or disabled player input releases mouse capture and blocks
camera look; closing UI restores capture when gameplay resumes.

## Deliberately deferred

- Ranged/projectile combat, production mocap, authored root-motion displacement,
  advanced controller UX, target cycling indicators, NPC combat AI intents, economy,
  factions, territory, governance, simulation LOD, multiplayer, and open-world
  streaming remain later work. No LLM proposal can execute player combat.
