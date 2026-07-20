# Stillpoint

> Hold the center. Break the swarm.

Stillpoint is a top-down survival shooter. The **supported runtime** is **Godot 4.7.x** with the **Compatibility (gl_compatibility)** renderer. Version **0.4.1** is a stability / architecture hardening release focused on movement, temporary weapon buffs, Continue/New Game, full run restore, bounds, and CI.

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
| **Continue** | Enabled only for a valid, non-expired, non-game-over run save. Restores the run. Does **not** clear the save. |
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

Run saves restore player, enemies, pickups, timers, difficulty, score, XP, HP, position, and status remaining times. **Projectiles are not saved** and are cleared on restore.

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

## Stability status (0.4.1)

Core loop is intended to be a stable base for later story / level content:

- Movement decelerates correctly when input is released
- Temporary weapon buffs refresh duration and do not permanently mutate `WeaponDefinition`
- Continue / New Game semantics are explicit
- Run restore covers player, enemies, pickups, and buffs
- Camera and actors respect world bounds; level has four physical walls
- Items spawn from `ItemDefinition` pools
- Audio buses receive settings volumes; `AudioManager` uses a small player pool

## License / contributing

See repository history and `legacy/python-tkinter/CONTRIBUTING.md` for prototype-era notes. Godot work should follow `docs/ARCHITECTURE.md`.
