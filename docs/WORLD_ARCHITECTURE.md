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
| `ActorFactory` | Spawn/restore actors from definitions |
| `InteractionIndex` | Region-scoped interactable queries |
| `DialogueCoordinator` | Condition/effect-driven dialogue |
| `QuestEventRouter` | Gameplay event → quest objective matching |
| `WorldSaveCoordinator` | Save v4 chunked persistence |
| `WorldSimulationService` | Virtual simulation hook for unloaded entities |
| `WorldFlagService` | Namespaced world flags |

## Identity Model

- **Definition ID** — what an entity is (`mira`, `herb`, `bandit`)
- **Persistent ID** — which instance in the world (`base:town/npc/mira`)
- **Snapshot** — serializable state when unloaded

Persistent IDs never use node names, instance IDs, or scene paths at runtime.

## Regions

Regions are independent scenes under `scenes/regions/`. Only the active region is loaded in `ActiveRegionSlot`. Player, pet, and mount persist in `PersistentRoot`.

## Quests & Dialogue

Quests advance via **Gameplay Events** routed through `QuestEventRouter`. Dialogue choices use **Conditions** and **Effects** resources — no quest-specific code in `DialogueRunner`.

## Save v4

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

v3 `user://world_save.json` is migrated automatically on Continue.

## Not Yet Implemented

- Seamless open-world streaming
- Adjacent region preload (interface reserved)
- Full offline ecosystem simulation

See also: `docs/ENTITY_ID_GUIDE.md`, `docs/SAVE_V4_GUIDE.md`, `docs/QUEST_CONDITION_EFFECT_GUIDE.md`, `docs/REGION_AUTHORING_GUIDE.md`.
