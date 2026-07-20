# Changelog

## 0.2.0

- Renamed the maintained game experience to Stillpoint.
- Replaced the monolithic root script with a modular `src/stillpoint` package.
- Separated the headless gameplay engine, Tk session lifecycle, and Canvas renderer.
- Added stable packaged-asset and user-data path handling.
- Replaced unsafe `eval()` autosave loading with validated JSON.
- Removed nested Tk event loops and consolidated lifecycle management.
- Reworked world/camera coordinates and frame-rate-independent movement.
- Added graceful image fallbacks, tests, lint configuration, and CI.
- Archived the previous final implementation under `legacy/`.
