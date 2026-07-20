# Architecture (Godot 0.5.0)

Stillpoint is an **isekai life-sim RPG foundation** on Godot 4.7 (Compatibility renderer). A legacy **2D survival shooter** remains under `scenes/gameplay/` for reference.

## Autoloads (RPG)

| Autoload | Responsibility |
| --- | --- |
| `EventBus` | Cross-system signals |
| `ResourceRegistry` | Static `.tres` index (characters, NPCs, items, quests, regions, …) |
| `InputBindingService` | Rebindable InputMap → `user://input_bindings.json` |
| `WorldTimeService` | In-game clock (day/hour/minute) |
| `RelationshipService` | Persistent player↔NPC affinity |
| `QuestManager` | Active quest runtime state |
| `GameManager` | Adventure / survival entry points |
| `SceneRouter` | Scene transitions |
| `SaveService` | Legacy survival run saves (v2) + settings |
| `WorldSaveService` | Partitioned world save (v3) |
| `AudioManager` | SFX / music |

Runtime actors (player, NPCs, pets, mounts) live in scenes — **not** autoloads.

## Character architecture

`CharacterController` (3D) composes:

- `HealthComponent`, `EnergyComponent`, `CombatComponent`, `SkillComponent`
- `RelationshipComponent`, `FactionComponent`, `InteractionComponent`
- `StatusEffectComponent`, optional `ScheduleComponent`

`PlayerController3D` adds movement states (walk/run toggle, jump, crouch, guard, attack). `NPCController` adds AI states and **attack consequence** handling.

## Interaction system

`Interactable` (Node3D) + `InteractionResolver` select targets by distance and priority. HUD prompts use `InputBindingService.get_display_text()` — never hard-coded keys.

## Relationship & combat consequences

- **Affinity** (−100…100) stored in `RelationshipService`
- **Disposition:** Friendly ≥ 50, Hostile ≤ −20, else Neutral
- Attacking friendly NPCs reduces affinity; attacking neutral NPCs flips to hostile
- Combat uses `Hitbox3D` / `Hurtbox3D` with windup/active/recovery phases

## World & regions

`WorldManager` owns region visibility, player spawn, save/load. `TransitionPortal` switches `town` / `wilderness` / `dungeon` regions in the vertical slice.

## Save schemas

### World save v3 (`WorldSaveService`)

```json
{
  "version": 3,
  "profile": {},
  "player": {},
  "world": {},
  "relationships": {},
  "quests": {},
  "inventory": {},
  "pets": {},
  "mounts": {},
  "regions": {}
}
```

### Legacy run save v2 (`SaveService`)

Still used by the survival prototype. See 0.4.2 notes below.

## Dialogue & quests

- `DialogueDefinition` → nodes + choices with affinity / quest effects
- `QuestDefinition` → objectives (talk, collect, deliver, …)
- `DialogueRunner` / `QuestManager` process data — no hard-coded NPC scripts

## Queue-free saveability (survival legacy)

`EnemyController.is_saveable()` / `PickupItem.is_saveable()` filter deferred `queue_free()` objects from run saves.

## Camera resize (survival legacy)

`CameraLimits.calculate_camera_limits()` + `Viewport.size_changed` in 2D gameplay.

## Future save policy

Saves with `version > SAVE_VERSION` are rejected (`future_version`). No auto-downgrade.

## Directory map

```text
scripts/
├── characters/     # PlayerController3D, NPCController, MovementMotor
├── components/     # Health, Energy, Combat, Inventory, …
├── interaction/    # Interactable, resolver, prompts
├── relationships/  # RelationshipService
├── dialogue/       # DialogueRunner
├── quests/         # QuestManager
├── world/          # WorldManager, portals, camera
├── pets/ mounts/   # PetController, MountController
├── time/           # WorldTimeService, ScheduleRunner
└── prototypes/     # Survival legacy scripts reference
```

## Vertical slice entry

`SceneRouter.VERTICAL_SLICE` → `scenes/world/vertical_slice.tscn`

## Reserved extension points

- Witness / crime / bounty systems (FactionDefinition.crime_rules)
- Agriculture, housing, festivals, marriage
- Skill trees, equipment visuals, AnimationTree
- Streaming open world (RegionDefinition.scene per region)
- U/I/O/L action slots
