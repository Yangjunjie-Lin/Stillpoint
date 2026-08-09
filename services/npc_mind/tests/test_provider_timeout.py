import asyncio
import logging

from app.repository import InMemoryRepository
from app.schemas import NpcGenerationRequest
from app.service import NpcCognitionService, _safe_provider_error_code


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
    assert result.reply_text.startswith("Hello. I'm here")
    assert "memory" not in result.reply_text.lower()


def test_provider_error_log_code_never_echoes_arbitrary_credential(caplog):
    credential = "examplecredential"

    class CredentialErrorProvider:
        async def generate_npc_reply(self, request):
            raise RuntimeError(credential)

    service = NpcCognitionService(
        repository=InMemoryRepository(), llm=CredentialErrorProvider()
    )
    with caplog.at_level(logging.WARNING, logger="app.service"):
        asyncio.run(
            service.handle_turn(
                NpcGenerationRequest(
                    request_id="credential-error",
                    player_profile_id="p",
                    world_save_id="w",
                    npc_definition_id="mira",
                    npc_persistent_id="mira-1",
                    session_id="s",
                    text="hello",
                )
            )
        )

    assert credential not in caplog.text
    assert "code=unclassified" in caplog.text
    assert _safe_provider_error_code(RuntimeError("provider_timeout")) == "provider_timeout"
    assert _safe_provider_error_code(RuntimeError("provider_http_429")) == "provider_http_429"
