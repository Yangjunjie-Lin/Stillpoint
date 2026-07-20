# Python + Tkinter prototype (archived)

This directory contains the pre-Godot Stillpoint prototype.

- **Git tag:** `v0.3-python-prototype`
- **Status:** historical reference only — not maintained as the primary game
- **Runtime:** Python 3.11+, Tkinter, Pillow

## Run the prototype (optional)

```bash
cd legacy/python-tkinter
python -m venv .venv
python -m pip install -e ".[dev]"
python -m stillpoint
```

## Relation to Godot

The Godot project does **not** import or execute this code at runtime. Behaviour here (combat math, enemy archetypes, XP curve) was re-implemented in typed GDScript under `scripts/` and `resources/`.
