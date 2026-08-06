from app.memory import MemoryRecord, consolidate


def test_consolidation_deduplicates_without_deleting_evidence():
    records = [
        MemoryRecord("a", "p", "w", "npc", "s", "episodic", "same", salience=0.5),
        MemoryRecord("b", "p", "w", "npc", "s", "episodic", "same", salience=0.9),
    ]
    result = consolidate(records)
    assert len(result) == 1
    assert {record.memory_id for record in records} == {"a", "b"}
