# Stillpoint

> An isekai life-sim RPG foundation — explore, live, relate, and fight when you choose to.

Stillpoint **0.6.0** adds **Jolt Physics** combat feedback on top of the **0.5.1 Vertical Slice**: animation-event attack windows, melee sweep, knockback, local hit stop, guard reactions, physics props, and **Combat Lab**.

## Modes

| Menu | Scene |
| --- | --- |
| **New Adventure / Continue** | `scenes/world/vertical_slice.tscn` (2.5D RPG) |
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
- Agriculture, housing, festivals, marriage
- Streaming open world

## Tests

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_runner.gd
python tools/python/validate_repo.py
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
