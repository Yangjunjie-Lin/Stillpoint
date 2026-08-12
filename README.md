# Stillpoint

> An isekai life-sim RPG foundation — explore, live, relate, and fight when you choose to.

Stillpoint **0.8.0** adds the NPC Cognitive Foundation on top of the 0.7.1 world architecture: authored NPC ontology, isolated memory, scoped knowledge graph, provider-agnostic dialogue, and deterministic offline fallback.

Stillpoint 0.8.0 keeps Save v4 compatible with 0.7.1; the optional `npc_cognition` section is versioned independently and absent sections restore as empty cognition state.

Save v4 validates the manifest and player core before Continue, recovers critical files from `.bak`, and returns safely to the menu if restore cannot complete. Runtime actors can be queued into an unloaded region, materialized under that region's `DynamicEntities`, saved across restart, and permanently destroyed without respawning. Required quest/dialogue effect failures are surfaced and retryable instead of being silently committed.

## Modes

| Menu | Scene |
| --- | --- |
| **New Adventure / Continue** | `scenes/world/world_session.tscn` (2.5D RPG) |
| **Combat Lab** | `scenes/combat/combat_lab.tscn` (combat sandbox) |
| **Survival Prototype** | `scenes/gameplay/gameplay.tscn` (legacy 2D shooter) |

## Physics

- **Backend:** built-in **Jolt Physics** (`physics/3d/physics_engine`)
- **Characters:** `CharacterBody3D` (not RigidBody)
- **Props:** `RigidBody3D` crates, destructible barrels
- **Interpolation:** enabled; teleports call `reset_physics_interpolation()`

## Controls (rebindable in Settings)

| Action | Default |
| --- | --- |
| Move | WASD |
| Interact | F |
| Walk/Run toggle | Space |
| Attack (3-hit combo) | J |
| Jump | K |
| Guard | Shift |
| Crouch | Ctrl |
| Pause / return menu | Esc |
| Combat debug overlay | F10 (diagnostics toggle) |
| Backpack / equipment | Tab |
| Select hotbar slot | 1–8, Q / E, mouse wheel |
| Use or equip selected item | X |

## Combat Lab

Main menu → **Combat Lab**. Demonstrates combo attacks, sweep hits, guard, knockback, crate push, barrel break, and bandit sparring. Animations are **placeholder** box rigs — see [docs/COMBAT_ANIMATION_GUIDE.md](docs/COMBAT_ANIMATION_GUIDE.md).

## Vertical Slice (life sim)

Town → Mira quest → wilderness herb → deliver; relationships, pets, mounts, autosave, and a real Main Menu → Continue → WorldSession restore path.

## Placeholder / not yet implemented

- Production character art & mocap animation
- Full AnimationTree blend trees per asset
- Full content pack / Mod pipeline
- Multi-slot save UI
- Seamless open world / adjacent region preload
- Full offline ecosystem / virtual combat simulation
- Cloud saves, multiplayer, threaded writers
- Agriculture, housing, festivals, marriage, weather, economy

Regions load one at a time; see [docs/WORLD_ARCHITECTURE.md](docs/WORLD_ARCHITECTURE.md).

## Tests

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_runner.gd
python tools/python/run_godot_tests.py
python tools/python/validate_repo.py
```

The automated gate currently runs 310 Godot tests with zero unexpected script
errors, errors, ObjectDB leaks, or resource leaks, plus 197 in-memory-applicable
NPC Mind backend tests and 7 PostgreSQL/pgvector integration tests. See
[`docs/NPC_COGNITION_0_8_0.md`](docs/NPC_COGNITION_0_8_0.md) for backend,
migration, authentication, privacy, and local transport setup.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
