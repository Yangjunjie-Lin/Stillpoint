from app.schemas import NpcGenerationResult


def test_structured_result_shape_is_explicit():
    result = NpcGenerationResult(reply_text="hello")
    assert result.proposed_intents == []
    assert result.memory_candidates == []
