from app.memory import MemoryRecord


def test_high_salience_is_retained_for_recall():
    record = MemoryRecord(
        "m",
        "p",
        "w",
        "npc",
        "s",
        "episodic",
        "attack at the gate",
        salience=1.0,
        half_life_hours=8760,
    )
    assert record.score("attack gate") > 0.1
