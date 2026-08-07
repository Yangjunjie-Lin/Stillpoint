from fastapi.testclient import TestClient

from app.auth import SessionTokenService
from app.config import Settings
from app.main import create_app
from app.repository import InMemoryRepository
from app.service import NpcCognitionService


SETTINGS = Settings(app_env="test", npc_mind_signing_key="memory-query-test-key")


class ProfileCapturingService(NpcCognitionService):
    captured_definition_id = ""
    captured_profile: dict = {}

    async def retrieve_memories_async(self, request, limit=None):
        del limit
        self.captured_definition_id = request.npc_definition_id
        self.captured_profile = request.npc_profile
        return []


def _headers() -> dict[str, str]:
    token, _ = SessionTokenService(SETTINGS).issue("player", "save", "install-1234")
    return {
        "Authorization": f"Bearer {token}",
        "X-Client-Install-ID": "install-1234",
    }


def test_memory_query_uses_deployed_npc_profile():
    repository = InMemoryRepository()
    service = ProfileCapturingService(settings=SETTINGS, repository=repository)
    repository.deploy_profile(service.catalog.get_profile("mira"), "player", "save", "mira-1")

    response = TestClient(create_app(service)).post(
        "/v1/npcs/mira-1/memories/query",
        headers=_headers(),
        json={"player_profile_id": "player", "world_save_id": "save", "query": "colour"},
    )

    assert response.status_code == 200
    assert service.captured_definition_id == "mira"
    assert service.captured_profile["identity"]["canonical_name"] == "Mira"
    assert service.captured_profile["goals"][0]["id"] == "serve_town"
