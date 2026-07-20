# Architecture

Stillpoint separates rules, presentation, storage, and application lifecycle instead of keeping every concern in one stateful script.

## Layers

- `menu.py` owns the application root and non-gameplay windows.
- `game.py` coordinates one session, input events, pause/boss overlays, autosaving, and the Tk frame schedule.
- `engine.py` contains the headless gameplay state, movement, collisions, spawning, scoring, effects, and snapshots.
- `render.py` translates world state into Tkinter Canvas drawing operations and camera coordinates.
- `models.py` contains typed domain objects and serialization boundaries.
- `storage.py` is the only module that reads or writes player data.
- `assets.py` loads and resizes artwork while providing drawing fallbacks.
- `config.py` centralizes balancing and rendering constants.
- `paths.py` makes packaged assets and writable data independent of the current working directory.

## Runtime flow

```text
MainMenu
   └── GameWindow
         ├── input events
         ├── fixed-cadence tick
         │     └── GameState.tick
         │           ├── movement and effects
         │           ├── enemies and bullets
         │           ├── pickups and collisions
         │           └── dynamic difficulty
         ├── GameRenderer.draw
         └── periodic JSON snapshot
```

Tkinter keeps a single application `mainloop()`. Game sessions schedule frames with `after()` instead of creating nested loops.

## Persistence

Autosaves and leaderboard entries use JSON and atomic replacement. Persisted content is never executed as Python code. Runtime data defaults to `~/.stillpoint/`, keeping Git status clean and allowing the project to run from any working directory.

## Extension points

- Add enemy types through `ObstacleBehavior`, engine movement dispatch, and renderer artwork mapping.
- Add power-ups through `ItemType`, `GameState.activate_item`, and the HUD colour map.
- Change balancing through `GameConfig` without editing the window controller.
- Replace Tkinter later while retaining `engine.py`, `models.py`, and `storage.py`.
