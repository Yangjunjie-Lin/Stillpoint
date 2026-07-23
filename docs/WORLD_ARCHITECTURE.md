# World Architecture (Stillpoint 0.7.0)

Stillpoint 0.7.0 replaces the monolithic `WorldManager` vertical slice with a **World Session** and dedicated **World Services**.

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

## Identity Model

- **Definition ID** — what an entity is (`mira`, `herb`, `bandit`)
- **Persistent ID** — which instance in the world (`base:town/npc/mira`)
- **Snapshot** — serializable state when unloaded

Persistent IDs never use node names, instance IDs, or scene paths at runtime. Renaming a Chest node does not break Restore.

## Static vs Spawn Actors

Region load order:

1. Load region scene
2. Register static entities
3. Hydrate region chunk snapshots into the repository
4. Restore snapshots onto static entities
5. Process spawn markers — `restore_actor(snapshot)` if present, else `spawn_actor`
6. Register interactables
7. Place persistent actors (spawn point) unless Continue restores saved transform

Destroyed snapshots are never respawned.

## NPC Base Prefab

`scenes/characters/base/npc_base_3d.tscn` is the production ActorFactory default. Dungeon Bandits spawn from `EntitySpawnMarker` + `EntitySpawnDefinition` through the factory.

## Regions

Regions are independent scenes under `scenes/regions/`. Only the active region is loaded in `ActiveRegionSlot`. Leaving a region captures its chunk and marks it dirty before the scene is freed.

Known regions come from `ResourceRegistry.get_all_regions()`, discovered regions, and manifest chunk maps — not a hard-coded three-map list.

## Quests & Dialogue

Quest lifecycle:

1. Start conditions → create runtime → start effects
2. Objective completion → objective completion effects
3. Quest complete → completion effects → reward effects (once; `rewards_claimed`)
4. Fail → failure effects

`StartQuestEffect` goes through `QuestCoordinator`, not bare `QuestManager.start_quest()`.

## Save v4

See `docs/SAVE_V4_GUIDE.md`. Main Menu uses `SaveSlotService` to detect Adventure saves without instantiating `WorldSession`.

## Not Yet Implemented

- Full content pack / Mod pipeline
- Multi-slot save UI
- Seamless open-world streaming / adjacent region preload
- Full offline ecosystem / virtual combat simulation
- Cloud saves / multiplayer / threaded writers
- Agriculture, housing, weather, economy

Do not claim these are complete in README marketing text.

See also: `docs/ENTITY_ID_GUIDE.md`, `docs/SAVE_V4_GUIDE.md`, `docs/QUEST_CONDITION_EFFECT_GUIDE.md`, `docs/REGION_AUTHORING_GUIDE.md`.
