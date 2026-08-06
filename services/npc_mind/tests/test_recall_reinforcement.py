from app.memory import MemoryRecord, reinforce


def test_recall_reinforcement_updates_auditable_fields():
    record = MemoryRecord("m", "p", "w", "npc", "s", "episodic", "fact")
    reinforce(record)
    assert record.recall_count == 1
    assert record.last_recalled_at
