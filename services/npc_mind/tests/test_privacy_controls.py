import asyncio

from app.repository import InMemoryRepository
from app.schemas import NpcGenerationRequest, NpcGenerationResult
from app.service import NpcCognitionService


class MemoryProposingProvider:
    async def generate_npc_reply(self, request):
        return NpcGenerationResult(
            reply_text="Understood.",
            memory_candidates=[
                {
                    "content": request.text,
                    "summary": "private preference",
                    "source_id": request.request_id,
                }
            ],
        )


def test_disabled_storage_and_personalization_persist_no_turn_or_memory():
    repository = InMemoryRepository()
    service = NpcCognitionService(repository=repository, llm=MemoryProposingProvider())
    request = NpcGenerationRequest(
        request_id="privacy-request",
        player_profile_id="privacy-player",
        world_save_id="privacy-save",
        npc_definition_id="mira",
        npc_persistent_id="base:town/npc/mira",
        session_id="privacy-session",
        text="My favorite color is blue.",
        allow_conversation_storage=False,
        allow_memory_personalization=False,
    )

    response = asyncio.run(service.handle_turn(request))
    session = repository.get_session(
        request.session_id,
        request.player_profile_id,
        request.world_save_id,
        request.npc_persistent_id,
    )

    assert response.memory_write_ids == []
    assert session is not None and session.turns == []
    assert repository.memories_for(
        request.player_profile_id,
        request.world_save_id,
        request.npc_persistent_id,
    ) == []
