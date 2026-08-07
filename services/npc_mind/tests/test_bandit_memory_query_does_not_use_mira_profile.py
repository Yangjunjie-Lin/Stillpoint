from fastapi.testclient import TestClient

from app.auth import SessionTokenService
from app.config import Settings
from app.main import create_app
from app.repository import InMemoryRepository
from app.service import NpcCognitionService


SETTINGS = Settings(app_env="test", npc_mind_signing_key="bandit-query-test-key")


class ProfileCapturingService(NpcCognitionService):
    captured_profile: dict = {}

    async def retrieve_memories_async(self, request, limit=None):
        del limit
        self.captured_profile = request.npc_profile
        return []


def test_bandit_memory_query_does_not_use_mira_profile():
    repository = InMemoryRepository()
    service = ProfileCapturingService(settings=SETTINGS, repository=repository)
    repository.deploy_profile(
        service.catalog.get_profile("bandit"), "player", "save", "bandit_0001"
    )
    token, _ = SessionTokenService(SETTINGS).issue("player", "save", "install-1234")

    response = TestClient(create_app(service)).post(
        "/v1/npcs/bandit_0001/memories/query",
        headers={
            "Authorization": f"Bearer {token}",
            "X-Client-Install-ID": "install-1234",
        },
        json={"player_profile_id": "player", "world_save_id": "save", "query": "route"},
    )

    assert response.status_code == 200
    assert service.captured_profile["identity"]["canonical_name"] == "Bandit"
    assert service.captured_profile["identity"]["canonical_name"] != "Mira"
    assert service.captured_profile["memory_policy"]["retrieval_limit"] == 8
