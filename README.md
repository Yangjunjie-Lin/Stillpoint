# Stillpoint

> An isekai life-sim RPG foundation — explore, live, relate, and fight when you choose to.

Stillpoint **0.7.0** hardens world architecture: dynamic region loading, persistent entity IDs, event-driven quests, Save v4, and data-driven dialogue/effects — on top of **0.6.0** Jolt combat and the **0.5.1** vertical slice.

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
| Combat debug overlay | F10 (diagnostics toggle) |
| Hotbar | Q / E |

## Combat Lab

Main menu → **Combat Lab**. Demonstrates combo attacks, sweep hits, guard, knockback, crate push, barrel break, and bandit sparring. Animations are **placeholder** box rigs — see [docs/COMBAT_ANIMATION_GUIDE.md](docs/COMBAT_ANIMATION_GUIDE.md).

## Vertical Slice (life sim)

Town → Mira quest → wilderness herb → deliver; relationships, pets, mounts, autosave, Continue.

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
python tools/python/validate_repo.py
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
