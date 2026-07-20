"""Safe JSON persistence for autosaves and leaderboard data."""

from __future__ import annotations

import json
from pathlib import Path
import time
from typing import Any, Mapping

from .config import SAVE_VERSION
from .models import LeaderboardEntry
from .paths import default_data_dir


class StorageError(RuntimeError):
    """Raised when user data cannot be written safely."""


class GameStorage:
    """Persists autosaves and leaderboards. Combat fields live in engine snapshots."""

    def __init__(self, data_dir: Path | None = None, leaderboard_size: int = 10):
        self.data_dir = (data_dir or default_data_dir()).expanduser()
        self.leaderboard_size = leaderboard_size
        self.autosave_path = self.data_dir / "autosave.json"
        self.leaderboard_path = self.data_dir / "leaderboard.json"
        self.save_version = SAVE_VERSION

    def _ensure_dir(self) -> None:
        self.data_dir.mkdir(parents=True, exist_ok=True)

    @staticmethod
    def _read_json(path: Path) -> Any | None:
        try:
            with path.open("r", encoding="utf-8") as handle:
                return json.load(handle)
        except (FileNotFoundError, json.JSONDecodeError, OSError, TypeError, ValueError):
            return None

    def _write_json(self, path: Path, payload: Any) -> None:
        self._ensure_dir()
        temporary = path.with_suffix(path.suffix + ".tmp")
        try:
            with temporary.open("w", encoding="utf-8") as handle:
                json.dump(payload, handle, ensure_ascii=False, indent=2)
                handle.write("\n")
            temporary.replace(path)
        except OSError as exc:
            temporary.unlink(missing_ok=True)
            raise StorageError(f"Unable to write {path}") from exc

    def save_autosave(self, snapshot: Mapping[str, Any]) -> None:
        payload = dict(snapshot)
        payload.setdefault("version", self.save_version)
        payload["saved_at"] = time.time()
        payload["is_game_over"] = False
        self._write_json(self.autosave_path, payload)

    def load_autosave(self, max_age_seconds: float) -> dict[str, Any] | None:
        payload = self._read_json(self.autosave_path)
        if not isinstance(payload, dict):
            return None
        if payload.get("is_game_over") is True:
            return None
        saved_at = payload.get("saved_at")
        if not isinstance(saved_at, (int, float)):
            return None
        if time.time() - float(saved_at) > max_age_seconds:
            return None
        return payload

    def mark_game_over(self) -> None:
        self._write_json(
            self.autosave_path,
            {"saved_at": time.time(), "is_game_over": True},
        )

    def clear_autosave(self) -> None:
        self.autosave_path.unlink(missing_ok=True)

    def load_leaderboard(self) -> list[LeaderboardEntry]:
        payload = self._read_json(self.leaderboard_path)
        if not isinstance(payload, list):
            return []

        entries: list[LeaderboardEntry] = []
        for item in payload:
            if not isinstance(item, dict):
                continue
            try:
                entries.append(LeaderboardEntry.from_dict(item))
            except (KeyError, TypeError, ValueError):
                continue

        return sorted(entries, reverse=True)[: self.leaderboard_size]

    def record_score(self, name: str, score: int) -> list[LeaderboardEntry]:
        safe_name = " ".join(name.strip().split())[:24] or "Player"
        entries = self.load_leaderboard()
        entries.append(LeaderboardEntry(score=max(0, int(score)), name=safe_name))
        entries = sorted(entries, reverse=True)[: self.leaderboard_size]
        self._write_json(self.leaderboard_path, [entry.to_dict() for entry in entries])
        return entries
