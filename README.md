# Stillpoint

> Hold the center. Break the swarm.

Stillpoint is a score-driven top-down survival shooter built with Python, Tkinter, and Pillow. Move with WASD, aim with the mouse, and survive increasingly dense enemy waves while collecting temporary weapon and movement upgrades.

## Highlights

- 360° mouse-directed shooting
- Three enemy behaviours: chase, avoid, and orbit
- Dynamic difficulty based on the current score
- Six temporary power-ups and weapon modifiers
- Safe JSON autosaves and a persistent local leaderboard
- Fullscreen, pause, diagnostics, and boss-screen modes
- Headless gameplay engine separated from Tkinter rendering
- Automated tests and GitHub Actions CI

## Requirements

- Python 3.11 or newer
- Tkinter, normally included with standard Python desktop installations

## Run from source

```bash
python -m venv .venv
```

Activate the environment, then install and launch:

```bash
python -m pip install -e .
python -m stillpoint
```

On Linux, install the operating-system Tk package when necessary, such as `python3-tk` on Debian or Ubuntu.

## Controls

| Input | Action |
| --- | --- |
| W / A / S / D | Move |
| Left click | Shoot toward the cursor |
| Escape | Pause or resume |
| B | Toggle the boss screen |
| F10 | Toggle diagnostics |
| F11 | Toggle fullscreen |

## Power-ups

| Colour | Effect | Duration |
| --- | --- | --- |
| Green | Shield | 10 seconds |
| Cyan | Speed boost | 5 seconds |
| Pink | Double score | 8 seconds |
| Orange | Double shot | 8 seconds |
| Red | Piercing shot | 8 seconds |
| Purple | Large shot | 8 seconds |

## Project layout

```text
Stillpoint/
├── src/stillpoint/
│   ├── assets/             # Packaged game artwork
│   ├── engine.py           # Headless gameplay rules and state
│   ├── game.py             # Tkinter session controller
│   ├── render.py           # Camera and Canvas rendering
│   ├── menu.py             # Application shell and menu windows
│   ├── models.py           # Typed domain models
│   └── storage.py          # Safe JSON persistence
├── tests/                  # Headless unit tests
├── docs/                   # Architecture notes
├── legacy/                 # Archived monolithic implementation
├── .github/workflows/      # Continuous integration
├── pyproject.toml          # Packaging and tool configuration
└── run.py                  # Development convenience entry point
```

Runtime saves are stored outside the repository in `~/.stillpoint/`. Set `STILLPOINT_DATA_DIR` to override that directory.

## Development

```bash
python -m pip install -e ".[dev]"
ruff check .
pytest
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the design and extension points.

## Legacy version

The original final single-file implementation remains available at `legacy/game_solution.py` for reference. Earlier prototypes remain accessible through Git history rather than cluttering the maintained source tree.
