"""Stable asset and writable-data paths independent of the launch directory."""

from __future__ import annotations

import os
from pathlib import Path


ASSET_DIR = Path(__file__).resolve().parent / "assets"


def asset_path(filename: str) -> Path:
    return ASSET_DIR / filename


def default_data_dir() -> Path:
    override = os.environ.get("STILLPOINT_DATA_DIR")
    if override:
        return Path(override).expanduser().resolve()
    return Path.home() / ".stillpoint"
