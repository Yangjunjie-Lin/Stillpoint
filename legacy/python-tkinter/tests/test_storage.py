from __future__ import annotations

import json
from pathlib import Path
import time

from stillpoint.storage import GameStorage


def test_leaderboard_is_sorted_and_limited(tmp_path: Path) -> None:
    storage = GameStorage(tmp_path, leaderboard_size=3)
    storage.record_score("Alpha", 10)
    storage.record_score("Beta", 30)
    entries = storage.record_score("Gamma", 20)
    entries = storage.record_score("Delta", 40)

    assert [(entry.name, entry.score) for entry in entries] == [
        ("Delta", 40),
        ("Beta", 30),
        ("Gamma", 20),
    ]


def test_autosave_round_trip(tmp_path: Path) -> None:
    storage = GameStorage(tmp_path)
    storage.save_autosave({"version": 3, "score": 42, "combat": {"level": 2}})

    restored = storage.load_autosave(max_age_seconds=60)
    assert restored is not None
    assert restored["score"] == 42
    assert restored["combat"]["level"] == 2
    assert restored["is_game_over"] is False
    assert restored["version"] == 3


def test_expired_or_corrupt_autosave_is_ignored(tmp_path: Path) -> None:
    storage = GameStorage(tmp_path)
    storage.autosave_path.write_text("not json", encoding="utf-8")
    assert storage.load_autosave(max_age_seconds=60) is None

    storage.autosave_path.write_text(
        json.dumps({"saved_at": time.time() - 120, "is_game_over": False}),
        encoding="utf-8",
    )
    assert storage.load_autosave(max_age_seconds=60) is None


def test_game_over_autosave_is_not_resumed(tmp_path: Path) -> None:
    storage = GameStorage(tmp_path)
    storage.mark_game_over()
    assert storage.load_autosave(max_age_seconds=60) is None
