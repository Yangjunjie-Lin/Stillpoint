# Region Authoring Guide

## Create a Region

1. Add `RegionDefinition` under `resources/regions/` with `id`, `scene`, and `default_spawn_id`.
2. Create scene under `scenes/regions/<name>/` with structure:

```
RegionRoot
├── Environment
├── StaticPhysics
├── Navigation
├── SpawnPoints
├── EntitySpawns
├── StaticEntities
├── DynamicEntities
├── Interactables
├── LocalEffects
└── RegionServices
```

3. Attach `WorldEntityIdentity` to every persistent entity (chests, pickups, destructibles, stateful doors, dynamic actors).
4. Use `TransitionPortal` for region exits.

## Spawning NPCs

1. Prefer `EntitySpawnMarker` + `EntitySpawnDefinition` over hand-copied component trees.
2. ActorFactory uses `scenes/characters/base/npc_base_3d.tscn` by default.
3. Set `definition_id`, `persistent_id`, and region on the spawn definition.
4. On load, markers call `restore_actor` when a snapshot exists, otherwise `spawn_actor`.

`DynamicEntities` is reserved for actors created at runtime or materialized from queued runtime snapshots. Do not add runtime instances to static definition resources. `RegionRuntimeService.get_dynamic_parent()` falls back to `StaticEntities`, then the Region root, only for older compatible scenes.

An unloaded-region spawn stores a snapshot and no SceneTree node. On entry, runtime snapshots are materialized after authored spawn markers, so persistent-ID checks prevent duplicates. A missing actor definition warns and leaves that snapshot queued while the rest of the region continues loading.

## Loading / Dirty Lifecycle

`RegionRuntimeService.enter_region()` is the only runtime entry point.

On unload:

1. Capture region chunk
2. Capture runtime actor transform and character/component state
3. Emit `region_chunk_captured`
4. Mark previous region dirty
5. Unregister entities and free the scene

Do not preload all regions in one scene.
