from datetime import datetime, timedelta, timezone

from app.memory import MemoryRecord, recency


def test_memory_decay_never_deletes_and_half_life_is_predictable():
    assert recency(24.0, 24.0) == 0.5
    record = MemoryRecord(
        "m",
        "p",
        "w",
        "npc",
        "s",
        "episodic",
        "old secret",
        created_at_real=(datetime.now(timezone.utc) - timedelta(days=30)).isoformat(),
    )
    assert record.archived is False
    assert record.score("old secret") > 0
