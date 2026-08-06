# World Architecture (Stillpoint 0.7.1)

Stillpoint 0.7.1 retains the 0.7 **World Session** and dedicated **World Services** architecture. This release only hardens runtime persistence and test reliability.

## WorldSession

Scene: `scenes/world/world_session.tscn`

```
WorldSession
├── PersistentRoot (Player, Pet, Mount)
├── ActiveRegionSlot (one loaded region)
├── WorldServices
├── CameraRig
├── WorldUI
└── DebugTools
```

`WorldManager` remains a thin compatibility alias extending `WorldSession`.

## World Services

| Service | Responsibility |
|---------|----------------|
| `RegionRuntimeService` | Dynamic region load/unload via `RegionDefinition.scene` |
| `WorldEntityRepository` | Persistent IDs, snapshots, dirty tracking |
| `ActorFactory` | Spawn/restore actors from definitions (`npc_base_3d.tscn`) |
| `InteractionIndex` | Region-scoped interactable queries |
| `DialogueCoordinator` | Condition/effect-driven dialogue |
| `QuestEventRouter` | Gameplay event → quest objective matching |
| `QuestCoordinator` | Quest lifecycle Conditions/Effects (start/objective/complete/fail/reward) |
| `WorldSaveCoordinator` | Save v4 chunked persistence |
| `SaveSlotService` | Filesystem save-slot queries (no session required) |
| `WorldSimulationService` | Virtual simulation hook for unloaded entities |
| `WorldFlagService` | Namespaced world flags |

`WorldSessionContext` does not cache the region selected at construction. `get_current_region_id()` resolves the live `RegionRuntimeService` value (or the session fallback) on every read. `RegionCondition` uses that world location; `EventMatchCondition` deliberately uses the immutable region recorded on its `GameplayEvent`.

## Identity Model

- **Definition ID** — what an entity is (`mira`, `herb`, `bandit`)
- **Persistent ID** — which instance in the world (`base:town/npc/mira`)
- **Snapshot** — serializable state when unloaded

Persistent IDs never use node names, instance IDs, or scene paths at runtime. Renaming a Chest node does not break Restore. Migration is the only place where old node names are mapped.

For every actor, `EntitySnapshot.region_id` (when restoring) overrides spawn context, which overrides the live region service. Before `_ready()`, `ActorFactory` applies the same normalized value to `WorldEntityIdentity.region_id` and `CharacterController.region_id`. An empty region rejects the spawn. Actor gameplay events resolve region from Identity → Controller → live region.

## Static vs Spawn Actors

Region load order:

1. Load region scene
2. Register static entities
3. Hydrate region chunk snapshots into the repository
4. Restore snapshots onto static entities
5. Process spawn markers — `restore_actor(snapshot)` if present, else `spawn_actor`
6. Materialize queued runtime snapshots under `DynamicEntities`
7. Register interactables
8. Place persistent actors (spawn point) unless Continue restores saved transform

Destroyed snapshots are never respawned.

An unloaded-region `SpawnEntityEffect` first validates its actor definition, then stores a snapshot with `persistent_id`, `definition_id`, `region_id`, `runtime_spawned`, `pending_spawn_id`, `entity_category`, and `destroyed=false`. Region entry skips destroyed/already-loaded/marker-owned snapshots and creates each remaining persistent ID once. Missing definitions are warned and retained so one bad snapshot cannot block the rest of the region. Unload captures transform and component state; permanent destruction preserves both `destroyed=true` and `runtime_spawned=true`.

## NPC Base Prefab

`scenes/characters/base/npc_base_3d.tscn` is the production ActorFactory default. Dungeon Bandits spawn from `EntitySpawnMarker` + `EntitySpawnDefinition` through the factory.

## Regions

Regions are independent scenes under `scenes/regions/`. Only the active region is loaded in `ActiveRegionSlot`. Leaving a region captures its chunk and marks it dirty before the scene is freed.

Known regions come from `ResourceRegistry.get_all_regions()`, discovered regions, and manifest chunk maps — not a hard-coded three-map list.

## Quests & Dialogue

Quest lifecycle:

1. Start conditions → start effects → commit Active runtime
2. Threshold check → objective completion effects → commit completion progress
3. Commit Completed state → retryable completion effects → retryable reward effects
4. Commit Failed state → retryable failure effects

`completion_effects_applied`, `failure_effects_applied`, and `rewards_claimed` change only after the required sequence succeeds. `QuestRuntime.applied_effect_ids` makes a repaired retry skip effects that already succeeded. Failure state is committed before failure effects; if those effects fail, the quest remains Failed and the effects may be retried.

`StartQuestEffect` goes through `QuestCoordinator`, not bare `QuestManager.start_quest()`.

## Save v4

See `docs/SAVE_V4_GUIDE.md`. Main Menu uses `SaveSlotService` to validate Adventure saves without instantiating `WorldSession`. A damaged Adventure slot disables Adventure Continue and never falls through to a Legacy Survival run. If session restore still fails, the world disables input and autosave, unloads partial region state, emits `restore_failed`, and returns to the menu without saving.

## Not Yet Implemented

- Full content pack / Mod pipeline
- Multi-slot save UI
- Seamless open-world streaming / adjacent region preload
- Full offline ecosystem / virtual combat simulation
- Cloud saves / multiplayer / threaded writers
- Agriculture, housing, weather, economy

Do not claim these are complete in README marketing text.

See also: `docs/ENTITY_ID_GUIDE.md`, `docs/SAVE_V4_GUIDE.md`, `docs/QUEST_CONDITION_EFFECT_GUIDE.md`, `docs/REGION_AUTHORING_GUIDE.md`.
