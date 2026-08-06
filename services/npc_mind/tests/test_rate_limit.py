import asyncio

from app.config import Settings
from app.repository import InMemoryRepository
from app.schemas import NpcGenerationRequest
from app.service import NpcCognitionService


def test_player_rate_limit_is_enforced():
    settings = Settings(player_rate_per_minute=1)
    service = NpcCognitionService(settings=settings, repository=InMemoryRepository())
    request = NpcGenerationRequest(
        request_id="one",
        player_profile_id="p",
        world_save_id="w",
        npc_definition_id="mira",
        npc_persistent_id="n",
        session_id="s",
        text="hello",
    )
    asyncio.run(service.handle_turn(request))
    try:
        asyncio.run(service.handle_turn(request.model_copy(update={"request_id": "two"})))
    except ValueError as error:
        assert str(error) == "player_rate_limited"
    else:
        raise AssertionError("rate limit did not reject the second request")
