# Stillpoint

> An isekai life-sim RPG foundation — explore, live, relate, and fight when you choose to.

Stillpoint **0.5.0** introduces a **2.5D / 3D** open-world life-simulation framework with relationships, quests, pets, mounts, and light action combat. The legacy **2D survival shooter** remains available as a separate prototype mode.

**Runtime:** Godot 4.7.x · **Compatibility (gl_compatibility)** renderer · Headless CI

## Requirements

- [Godot 4.7.1 Stable](https://godotengine.org/download/archive/4.7.1-stable/)
- No Python required to play or export

## Run

1. Open the repo in Godot Project Manager.
2. Press **F5** (`scenes/bootstrap/main.tscn`).

### Main menu

| Button | Behaviour |
| --- | --- |
| **New Adventure** | Starts the 2.5D vertical slice (`scenes/world/vertical_slice.tscn`) |
| **Continue** | Resumes world save (`user://world_save.json`) or legacy survival run |
| **Survival Prototype** | Legacy 2D shooter (`scenes/gameplay/gameplay.tscn`) |

### Default controls (rebindable via `InputBindingService`)

| Action | Key |
| --- | --- |
| Move | WASD |
| Interact | F |
| Walk / Run toggle | Space |
| Attack | J |
| Jump | K |
| Guard | Shift |
| Crouch | Ctrl |
| Hotbar prev / next | Q / E |
| Pause / Menu / Map | Esc / Tab / M |

UI shows the **current bound key** — never hard-coded labels.

## Architecture (0.5.0)

- **3D world:** `CharacterBody3D`, `Area3D`, `NavigationAgent3D`, `Camera3D`
- **Components:** Health, Energy, Combat, Skills, Interaction, Relationship, Faction, Inventory, Schedule
- **Systems:** Dialogue, Quests, World time, Regions, Pets, Mounts
- **Saves:** Partitioned world save schema **v3** (`profile`, `player`, `world`, `relationships`, `quests`, `inventory`, `pets`, `mounts`, `regions`)
- **Data-driven:** NPCs, items, dialogues, quests, regions, factions via `ResourceRegistry` autoload

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for full design notes.

## Vertical slice

`scenes/world/vertical_slice.tscn` includes:

- Town, wilderness, and dungeon test regions
- NPCs Mira (friendly) and Ren (neutral), plus a hostile bandit
- Pet (follow/stay), mount (ride/dismount), chest, herb pickup
- Demo quest **Mira's Errand** (talk → collect → deliver)
- NPC attack consequences (affinity / disposition changes)

## Legacy survival prototype

Preserved at `scenes/gameplay/` and documented in `scenes/prototypes/survival/README.md`. Not mixed with RPG runtime state.

## Tests & CI

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_runner.gd
godot --headless --path . --export-debug "Linux" builds/stillpoint_linux.x86_64
godot --headless --path . --export-debug "Windows Desktop" builds/stillpoint_windows.exe
python tools/python/validate_repo.py
```

## Version history

| Version | Focus |
| --- | --- |
| **0.5.0** | 2.5D RPG framework + vertical slice |
| **0.4.2** | Save validation, Continue, multi-level restore (survival) |
| **0.4.x** | 2D survival shooter prototype |
