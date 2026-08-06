# Entity ID Guide

## Persistent ID Format

```
base:<region>/<category>/<instance>
```

Examples:

- `base:town/npc/mira`
- `base:town/interactable/chest_0001`
- `base:wilderness/pickup/herb_0001`
- `base:dungeon/npc/bandit_0001`
- `base:dungeon/npc/bandit_0002`
- `base:player/main`

## Rules

1. Every mutable persistent entity has a `WorldEntityIdentity` node and an explicit `PersistencePolicy`.
2. Persistent IDs are unique within a world session.
3. Definition IDs may be shared across instances (two Bandits can share `bandit`).
4. Runtime spawns use `WorldSaveCoordinator.next_runtime_id()` / `PersistentIdGenerator` — counters persist in `global_world.json`.
5. Node renames do not affect saves — identity is the persistent ID, not the node name.
6. Talk proxies / portals without state may use `PersistencePolicy.NONE` deliberately.

## Actor Region Invariant

For a loaded actor:

```text
WorldEntityIdentity.region_id
== CharacterController.region_id
== EntitySnapshot.region_id
```

Restore snapshot region wins over spawn context; spawn context wins over the live `RegionRuntimeService`. `ActorFactory` rejects an empty region or a missing explicit persistent ID before scene instantiation, and synchronizes Identity and Controller before `_ready()`.

## Runtime Snapshot Metadata

Runtime actors persist `runtime_spawned=true`, a `pending_spawn_id` for unloaded-region placement, and `entity_category="actor"`. The repository preserves these fields while recapturing live transforms/components. A permanent destroy sets `destroyed=true` without clearing `runtime_spawned`; later region loads retain the snapshot but never instantiate it.

## Chunk Filenames

`RegionIdUtil.to_chunk_filename("base:town")` → `base_town`  
`RegionIdUtil.from_chunk_filename("base_town.json")` → `base:town`  

Manifest `region_chunks` stores the authoritative ID → filename map.

## Migration

Legacy v3 saves map node names to persistent IDs only inside `SaveV3MigrationMapping`. The same migration converts NPC data into `components.character`, Chest data into `components.chest`, and Pickup data into `components.pickup`; runtime ID generation never uses node names.
