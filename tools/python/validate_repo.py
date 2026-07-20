#!/usr/bin/env python3
"""Repository hygiene checks for Stillpoint CI (reference tooling only)."""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

README_REQUIRED_PATHS = [
    "project.godot",
    "scenes/bootstrap/main.tscn",
    "scenes/gameplay/gameplay.tscn",
    "legacy/python-tkinter",
    "docs/ARCHITECTURE.md",
    "tests/test_runner.gd",
]

RUNTIME_SAVE_NAMES = {
    "run_save.json",
    "settings.json",
    "leaderboard.json",
    "autosave.json",
}

FORBIDDEN_PREFIXES = (
    ".godot/",
    "builds/",
    "export/",
)

FORBIDDEN_SUFFIXES = (
    ".tmp",
    ".bak",
)

FORBIDDEN_BUILD_SUFFIXES = (
    ".exe",
    ".x86_64",
    ".pck",
)


def is_runtime_save(path: str) -> bool:
    normalized = path.replace("\\", "/")
    if normalized.startswith("legacy/python-tkinter/"):
        return False
    return Path(normalized).name in RUNTIME_SAVE_NAMES


def git_ls_files() -> list[str]:
    result = subprocess.run(
        ["git", "ls-files"],
        cwd=ROOT,
        check=True,
        capture_output=True,
        text=True,
    )
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def main() -> int:
    errors: list[str] = []
    tracked = git_ls_files()

    for rel in tracked:
        normalized = rel.replace("\\", "/")
        for prefix in FORBIDDEN_PREFIXES:
            if normalized.startswith(prefix):
                errors.append(f"Tracked forbidden path: {rel}")
        for suffix in FORBIDDEN_SUFFIXES:
            if normalized.endswith(suffix):
                errors.append(f"Tracked forbidden artifact: {rel}")
        if normalized.startswith("builds/") or normalized.startswith("export/"):
            for suffix in FORBIDDEN_BUILD_SUFFIXES:
                if normalized.endswith(suffix):
                    errors.append(f"Tracked build artifact: {rel}")
        if is_runtime_save(normalized):
            errors.append(f"Tracked runtime save file: {rel}")

    abs_path = re.compile(r"[A-Za-z]:\\Users\\|C:/Users/")
    for rel in tracked:
        if rel.replace("\\", "/") == "tools/python/validate_repo.py":
            continue
        path = ROOT / rel
        if path.suffix.lower() not in {".gd", ".tscn", ".tres", ".md", ".yml", ".yaml", ".cfg", ".py", ".txt"}:
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        if abs_path.search(text):
            errors.append(f"Possible absolute local path in {rel}")

    for required in README_REQUIRED_PATHS:
        if not (ROOT / required).exists():
            errors.append(f"Required path missing on disk: {required}")

    id_re = re.compile(r'^id = &"([^"]+)"', re.M)
    seen: dict[str, str] = {}
    for path in (ROOT / "resources").rglob("*.tres"):
        text = path.read_text(encoding="utf-8", errors="ignore")
        match = id_re.search(text)
        if not match:
            continue
        rid = match.group(1)
        key = f"{path.parent.name}:{rid}"
        rel = str(path.relative_to(ROOT)).replace("\\", "/")
        if key in seen:
            errors.append(f"Duplicate resource id {rid} in {rel} and {seen[key]}")
        else:
            seen[key] = rel

    if errors:
        print("Repository validation FAILED:")
        for err in errors:
            print(f"  - {err}")
        return 1

    print("Repository validation OK (%d tracked files)" % len(tracked))
    return 0


if __name__ == "__main__":
    sys.exit(main())
