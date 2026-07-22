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
├── Interactables
├── LocalEffects
└── RegionServices
```

3. Attach `WorldEntityIdentity` to every persistent entity.
4. Use `TransitionPortal` for region exits.

## Spawning

Prefer `EntitySpawnMarker` + `EntitySpawnDefinition` over duplicating full NPC component trees.

## Loading

`RegionRuntimeService.enter_region()` is the only runtime entry point — do not preload all regions in one scene.
