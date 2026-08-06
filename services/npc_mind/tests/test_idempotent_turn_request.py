import asyncio

from app.repository import InMemoryRepository
from app.schemas import NpcGenerationRequest
from app.service import NpcCognitionService


def test_retry_is_idempotent():
    service = NpcCognitionService(repository=InMemoryRepository())
    request = NpcGenerationRequest(
        request_id="same",
        player_profile_id="p",
        world_save_id="w",
        npc_definition_id="mira",
        npc_persistent_id="mira-1",
        session_id="s",
        text="hello",
    )
    first = asyncio.run(service.handle_turn(request))
    second = asyncio.run(service.handle_turn(request))
    assert first.model_dump() == second.model_dump()
    assert len(service.repository.sessions["s"].turns) == 2
