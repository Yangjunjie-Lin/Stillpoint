import asyncio

from app.repository import InMemoryRepository
from app.schemas import NpcGenerationRequest
from app.service import NpcCognitionService


def test_old_turns_roll_into_summary():
    service = NpcCognitionService(repository=InMemoryRepository())
    for index in range(11):
        asyncio.run(
            service.handle_turn(
                NpcGenerationRequest(
                    request_id=f"r{index}",
                    player_profile_id="p",
                    world_save_id="w",
                    npc_definition_id="mira",
                    npc_persistent_id="mira-1",
                    session_id="s",
                    text=f"hello {index}",
                )
            )
        )
    session = service.repository.sessions["s"]
    assert len(session.turns) <= 8
    assert session.rolling_summary
