from fastapi.testclient import TestClient

from app.auth import SessionTokenService
from app.config import Settings
from app.main import create_app
from app.repository import InMemoryRepository
from app.service import NpcCognitionService


def test_memory_query_unknown_npc_instance():
    settings = Settings(app_env="test", npc_mind_signing_key="unknown-instance-test-key")
    service = NpcCognitionService(settings=settings, repository=InMemoryRepository())
    token, _ = SessionTokenService(settings).issue("player", "save", "install-1234")

    response = TestClient(create_app(service)).post(
        "/v1/npcs/not-deployed/memories/query",
        headers={
            "Authorization": f"Bearer {token}",
            "X-Client-Install-ID": "install-1234",
        },
        json={"player_profile_id": "player", "world_save_id": "save", "query": "memory"},
    )

    assert response.status_code == 404
    assert response.json()["detail"] == "unknown_npc_instance"
