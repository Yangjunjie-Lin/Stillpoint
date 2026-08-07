import asyncio

from app.providers import FakeEmbeddingProvider
from app.repository import InMemoryRepository
from app.schemas import NpcGenerationRequest
from app.service import NpcCognitionService


class InvalidProvider:
    async def generate_npc_reply(self, request):
        return {"reply_text": 42}


def test_invalid_output_uses_safe_fallback_and_writes_no_memory():
    service = NpcCognitionService(
        repository=InMemoryRepository(), llm=InvalidProvider(), embeddings=FakeEmbeddingProvider()
    )
    request = NpcGenerationRequest(
        request_id="bad",
        player_profile_id="p",
        world_save_id="w",
        npc_definition_id="mira",
        npc_persistent_id="mira-1",
        session_id="s",
        text="remember this secret",
    )
    response = asyncio.run(service.handle_turn(request))
    assert response.reply_text.startswith("Hello. I'm here")
    assert service.repository.memories == {}


def test_chinese_failure_fallback_does_not_claim_memory_is_missing():
    service = NpcCognitionService(
        repository=InMemoryRepository(), llm=InvalidProvider(), embeddings=FakeEmbeddingProvider()
    )
    request = NpcGenerationRequest(
        request_id="bad-chinese",
        player_profile_id="p",
        world_save_id="w",
        npc_definition_id="mira",
        npc_persistent_id="mira-1",
        session_id="s",
        text="你好",
    )
    response = asyncio.run(service.handle_turn(request))
    assert response.degraded is True
    assert "检索" not in response.reply_text
    assert "记忆" not in response.reply_text
