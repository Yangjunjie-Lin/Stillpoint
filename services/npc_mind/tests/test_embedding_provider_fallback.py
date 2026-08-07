import asyncio

from app.repository import InMemoryRepository
from app.schemas import NpcGenerationRequest
from app.service import NpcCognitionService


class UnavailableEmbeddingProvider:
    async def embed(self, texts):
        del texts
        raise TimeoutError("embedding timeout")


def test_embedding_timeout_keeps_valid_reply_and_skips_memory_write():
    repository = InMemoryRepository()
    service = NpcCognitionService(
        repository=repository,
        embeddings=UnavailableEmbeddingProvider(),
    )
    result = asyncio.run(
        service.handle_turn(
            NpcGenerationRequest(
                request_id="embedding-timeout",
                player_profile_id="p",
                world_save_id="w",
                npc_definition_id="mira",
                npc_persistent_id="mira-1",
                session_id="s",
                text="Please remember my favorite color is blue.",
            )
        )
    )

    assert result.reply_text
    assert result.degraded is True
    assert result.degradation_reason == (
        "memory_retrieval_unavailable,memory_embedding_unavailable"
    )
    assert result.memory_write_ids == []
    assert repository.memories_for("p", "w", "mira-1") == []
