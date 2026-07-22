# Stillpoint

> An isekai life-sim RPG foundation — explore, live, relate, and fight when you choose to.

Stillpoint **0.5.1** is a **runnable Vertical Slice** on Godot 4.7 (Compatibility renderer): Town → dialogue → quest → wilderness gather → deliver, plus combat consequences, pet/mount, region travel, and world save/continue.

## Modes

| Menu | Scene |
| --- | --- |
| **New Adventure / Continue** | `scenes/world/vertical_slice.tscn` (2.5D RPG) |
| **Survival Prototype** | `scenes/gameplay/gameplay.tscn` (legacy 2D shooter) |

## Controls (rebindable in Settings)

| Action | Default |
| --- | --- |
| Move | WASD |
| Interact | F |
| Walk/Run toggle | Space |
| Attack | J |
| Jump | K |
| Guard | Shift |
| Crouch | Ctrl |
| Hotbar | Q / E |
| Pause / Menu / Map | Esc / Tab / M |

## Vertical Slice checklist

1. Stand on Town ground; move, jump, crouch, walk/run.
2. Talk to Mira; accept errand.
3. Portal to Wilderness; pick up Herb.
4. Return; deliver to Mira; reward + affinity.
5. Attack Mira (affinity drop / flee); attack Ren (hostile).
6. Enter Dungeon; Bandit is hostile.
7. Guard reduces frontal damage.
8. Pet Follow/Stay; Mount ride/dismount.
9. Autosave / return to menu; Continue restores state.

## Saves

| File | Purpose |
| --- | --- |
| `user://world_save.json` | Adventure world save (schema **v3**) |
| `user://input_bindings.json` | Key bindings |
| `user://run_save.json` | Legacy survival run (v2) |

## Placeholder / not yet implemented

- Formal art & AnimationTree
- Agriculture, housing, festivals, marriage
- Full crime/witness/bounty
- Streaming open world
- Complex skill trees

## Tests

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_runner.gd
python tools/python/validate_repo.py
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
