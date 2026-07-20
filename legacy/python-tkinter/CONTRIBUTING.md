# Contributing

1. Create a focused branch from `main`.
2. Install development dependencies with `python -m pip install -e ".[dev]"`.
3. Run `ruff check .` and `pytest` before opening a pull request.
4. Keep gameplay constants in `config.py` and persistence code in `storage.py`.
5. Do not commit local autosaves, leaderboards, virtual environments, or generated caches.
