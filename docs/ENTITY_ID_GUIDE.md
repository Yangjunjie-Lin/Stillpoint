# Entity ID Guide

## Persistent ID Format

```
base:<region>/<category>/<instance>
```

Examples:

- `base:town/npc/mira`
- `base:wilderness/pickup/herb_0001`
- `base:dungeon/npc/bandit_0001`
- `base:player/main`

## Rules

1. Every persistent entity has a `WorldEntityIdentity` node.
2. Persistent IDs are unique within a world session.
3. Definition IDs may be shared across instances.
4. Runtime spawns use `PersistentIdGenerator` — never random per-boot UUIDs for fixed content.
5. Node renames do not affect saves.

## Migration

Legacy v3 saves map node names to persistent IDs only inside `SaveV3MigrationMapping`.
