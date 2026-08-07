from __future__ import annotations

import uuid

from app.config import Settings
from app.repository import PostgresCognitionRepository
from app.schemas import NpcGenerationRequest
from app.service import NpcCognitionService


def scope() -> tuple[str, str, str]:
    suffix = uuid.uuid4().hex
    return f"player-{suffix}", f"save-{suffix}", f"npc-{suffix}"


def service(database_url: str) -> NpcCognitionService:
    settings = Settings(app_env="test", database_url=database_url)
    return NpcCognitionService(
        settings=settings, repository=PostgresCognitionRepository(database_url)
    )


def request(
    player: str,
    save: str,
    npc: str,
    *,
    request_id: str = "request-1",
    session_id: str | None = None,
    text: str = "Remember that my favorite color is blue.",
    definition: str = "mira",
) -> NpcGenerationRequest:
    return NpcGenerationRequest(
        request_id=request_id,
        player_profile_id=player,
        world_save_id=save,
        npc_definition_id=definition,
        npc_persistent_id=npc,
        session_id=session_id or f"session-{npc}",
        text=text,
    )
