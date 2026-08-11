# Windows Quick Start

Double-click `START_STILLPOINT.cmd` in the repository root, or use the desktop
shortcut `Stillpoint 0.8.0.lnk`.

The desktop shortcut and Windows Debug export use the shared Stillpoint emblem
at `assets/ui/stillpoint_emblem.ico`; the in-game UI uses its scalable SVG source.

The launcher starts, in order:

1. PostgreSQL + pgvector;
2. Alembic migrations;
3. Uvicorn on `127.0.0.1:8443` using the configured provider environment;
4. the Stillpoint Debug Build.

The game window and the launcher share one lifecycle. Close the Debug Build (or
the launcher window) to stop the backend and PostgreSQL container automatically.
The launcher uses provider credentials only from environment variables; no key
is stored in the shortcut or in the repository.

To recreate the desktop shortcut after moving the repository, run from the
repository root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\windows\create_desktop_shortcut.ps1
```

If port `8443` is already occupied, close the existing Debug Build or run
`tools/windows/stop_interactive_e2e.ps1` before starting again.
