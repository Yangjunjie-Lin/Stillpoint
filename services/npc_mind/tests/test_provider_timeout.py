import asyncio

from app.repository import InMemoryRepository
from app.schemas import NpcGenerationRequest
from app.service import NpcCognitionService


class TimeoutProvider:
    async def generate_npc_reply(self, request):
        raise TimeoutError("provider timeout")


def test_provider_timeout_falls_back_without_blocking_gameplay():
    service = NpcCognitionService(repository=InMemoryRepository(), llm=TimeoutProvider())
    result = asyncio.run(
        service.handle_turn(
            NpcGenerationRequest(
                request_id="timeout",
                player_profile_id="p",
                world_save_id="w",
                npc_definition_id="mira",
                npc_persistent_id="mira-1",
                session_id="s",
                text="hello",
            )
        )
    )
    assert result.reply_text.startswith("I can't reach")
