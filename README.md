# Stillpoint

> Hold the center. Break the swarm.

Stillpoint is a top-down survival shooter. The **supported runtime** is **Godot 4.7.x**. The earlier Python + Tkinter build is archived as a historical prototype and is no longer the primary development target.

## Requirements

- [Godot 4.7.1 Stable](https://godotengine.org/download/archive/4.7.1-stable/) (or any 4.7.x stable)
- No Python runtime is required to play or export the Godot game

## Run (Godot)

1. Install Godot 4.7.x Stable.
2. Open this repository folder in the Godot Project Manager.
3. Press **F5** (main scene: `scenes/bootstrap/main.tscn`).

### Controls (InputMap)

| Action | Default |
| --- | --- |
| Move | WASD |
| Shoot | Left mouse |
| Pause | Escape |
| Fullscreen | F11 |
| Diagnostics | F10 |

## Project layout

```text
Stillpoint/
├── project.godot
├── assets/                 # Art, audio, fonts
├── scenes/                 # Bootstrap, gameplay, actors, UI, levels
├── scripts/                # Typed GDScript (core, components, actors, UI)
├── resources/              # Data-driven .tres definitions
├── tests/                  # Headless GDScript tests
├── tools/python/           # Offline helpers only (not a game dependency)
├── docs/                   # Architecture notes
└── legacy/python-tkinter/  # Frozen Python prototype (reference only)
```

## Headless tests

```bash
godot --headless --path . --editor --quit-after 3
godot --headless --path . --script res://tests/test_runner.gd
```

## Legacy Python prototype

Tag: `v0.3-python-prototype`

Location: `legacy/python-tkinter/`

That tree is kept for behaviour reference and course-history continuity. It is **not** linked to the Godot runtime (no Python subprocess, RPC, or bindings). See `legacy/python-tkinter/README.md`.

Old `~/.stillpoint/` JSON saves are **not** loaded by Godot. Start a new run, or use `tools/python/` offline converters if you later need a one-shot migration.

## Saves

Godot writes to `user://`:

- `run_save.json` — current run
- `settings.json` — display / audio settings
- `leaderboard.json` — local high scores

## License / contributing

See repository root history and `legacy/python-tkinter/CONTRIBUTING.md` for the prototype-era notes. Godot contributions should follow the scene/component boundaries in `docs/ARCHITECTURE.md`.
