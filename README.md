# Stillpoint

> Hold the center. Break the swarm.

Stillpoint is a top-down survival shooter. The **supported runtime** is **Godot 4.7.x** with the **Compatibility (gl_compatibility)** renderer. Version **0.4.2** hardens save validation, Continue semantics, multi-level restore, camera resize, and regression tests on top of the 0.4.1 gameplay base.

The earlier Python + Tkinter build is archived as a historical prototype and is not required to play.

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

### Main menu

| Button | Behaviour |
| --- | --- |
| **Continue** | Enabled only for a valid, non-expired, non-game-over run save with a known `level_id`. Restores the **saved player name** (menu input is ignored). Does **not** clear the save. |
| **New Game** | If a valid run exists, shows an in-game confirm panel. Clears the old run only after confirm. |
| **Settings** | Applies master / music / SFX bus volumes and fullscreen. |
| **Quit** | Exits. |

Leaderboard entries are listed on the menu.

## Project layout

```text
Stillpoint/
├── project.godot
├── default_bus_layout.tres # Master / Music / SFX
├── assets/
├── scenes/
├── scripts/
├── resources/              # Enemy / Item / Weapon / Level .tres
├── tests/                  # Headless GDScript tests (auto-scanned)
├── tools/python/           # Offline helpers + repo validation
├── docs/ARCHITECTURE.md
└── legacy/python-tkinter/  # Frozen Python prototype (reference only)
```

## Saves

Godot writes under `user://` (OS app data for Stillpoint):

| File | Purpose |
| --- | --- |
| `run_save.json` | Current run (SAVE_VERSION **2**) |
| `settings.json` | Display / audio |
| `leaderboard.json` | Local high scores |

Run saves restore player, enemies, pickups, timers, difficulty, score, XP, HP, position, status remaining times, and **`level_id`** (loads the matching `LevelDefinition` before spawning). Dead or `queue_free()` enemies/pickups are **not** saved. Saves from a **newer game version** or with an **unknown level** cannot be continued.

**Projectiles are not saved** and are cleared on restore.

Old Python `~/.stillpoint/` saves are **not** loaded.

## Headless tests

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_runner.gd
```

## Export

```bash
godot --headless --path . --export-debug "Linux" builds/stillpoint_linux.x86_64
godot --headless --path . --export-debug "Windows Desktop" builds/stillpoint_windows.exe
```

CI fails if either artifact is missing (`if-no-files-found: error`).

## CI

GitHub Actions (`.github/workflows/ci.yml`):

1. Godot import
2. Headless tests
3. Linux debug export + artifact
4. Windows debug export + artifact
5. Legacy Python prototype tests (**reference only**)
6. Repository validation (`tools/python/validate_repo.py`)

## Legacy Python prototype

Annotated tag: **`v0.3-python-prototype`** → commit `41d92ef9d1377cfd3764b7b8fba0aaebbc6d4d7c` (final Python/Tkinter tree before Godot migration).

Location: `legacy/python-tkinter/`

Not linked to the Godot runtime (no Python subprocess, RPC, or bindings). See `legacy/python-tkinter/README.md`.

```bash
cd legacy/python-tkinter
python -m pip install -e ".[dev]"
ruff check .
pytest
```

## Stability status (0.4.2)

Pre-story stable base:

- Death / queued enemies and pickups filtered from saves; old dead enemies skipped on restore
- Continue restores saved player name and level (`level_id`)
- Strict save validation (finite numbers, required fields, future versions rejected)
- Camera limits recalculate on viewport resize
- Expanded headless tests (bad saves, atomic write failure, pause clocks, smoke restore)

## License / contributing

See repository history and `legacy/python-tkinter/CONTRIBUTING.md` for prototype-era notes. Godot work should follow `docs/ARCHITECTURE.md`.
