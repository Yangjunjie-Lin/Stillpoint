import asyncio

from app.repository import InMemoryRepository
from app.schemas import NpcGenerationRequest
from app.service import NpcCognitionService


def test_old_memory_can_be_recalled_by_entity_or_semantic_query():
    service = NpcCognitionService(repository=InMemoryRepository())
    asyncio.run(
        service.handle_turn(
            NpcGenerationRequest(
                request_id="r1",
                player_profile_id="p",
                world_save_id="w",
                npc_definition_id="mira",
                npc_persistent_id="mira-1",
                session_id="s",
                text="I told you a secret about the blue herb.",
            )
        )
    )
    request = NpcGenerationRequest(
        request_id="r2",
        player_profile_id="p",
        world_save_id="w",
        npc_definition_id="mira",
        npc_persistent_id="mira-1",
        session_id="s",
        text="Do you remember the blue herb?",
    )
    assert service.retrieve_memories(request)
