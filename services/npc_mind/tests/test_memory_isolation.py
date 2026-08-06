import asyncio

from app.repository import InMemoryRepository
from app.schemas import NpcGenerationRequest
from app.service import NpcCognitionService


def _request(request_id: str, player: str, npc: str, text: str) -> NpcGenerationRequest:
    return NpcGenerationRequest(
        request_id=request_id,
        player_profile_id=player,
        world_save_id="save",
        npc_definition_id="bandit",
        npc_persistent_id=npc,
        session_id=f"session-{npc}",
        text=text,
    )


def test_two_instances_and_players_do_not_share_memory():
    service = NpcCognitionService(repository=InMemoryRepository())
    asyncio.run(
        service.handle_turn(
            _request("r1", "player-a", "bandit-1", "I told you a secret about blue.")
        )
    )
    assert len(service.repository.memories_for("player-a", "save", "bandit-1")) == 1
    assert service.repository.memories_for("player-a", "save", "bandit-2") == []
    assert service.repository.memories_for("player-b", "save", "bandit-1") == []
