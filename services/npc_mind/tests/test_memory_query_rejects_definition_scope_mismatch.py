from fastapi.testclient import TestClient

from app.auth import SessionTokenService
from app.config import Settings
from app.main import create_app
from app.repository import InMemoryRepository
from app.service import NpcCognitionService


def test_memory_query_rejects_definition_scope_mismatch():
    settings = Settings(app_env="test", npc_mind_signing_key="scope-mismatch-test-key")
    repository = InMemoryRepository()
    service = NpcCognitionService(settings=settings, repository=repository)
    repository.deploy_profile(service.catalog.get_profile("mira"), "player", "save", "mira-1")
    token, _ = SessionTokenService(settings).issue("player", "save", "install-1234")

    response = TestClient(create_app(service)).post(
        "/v1/npcs/mira-1/memories/query",
        headers={
            "Authorization": f"Bearer {token}",
            "X-Client-Install-ID": "install-1234",
        },
        json={
            "player_profile_id": "player",
            "world_save_id": "save",
            "npc_definition_id": "bandit",
            "query": "What do you remember?",
        },
    )

    assert response.status_code == 409
    assert response.json()["detail"] == "npc_definition_scope_mismatch"
