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
    assert response.reply_text.startswith("I can't reach")
    assert service.repository.memories == {}
