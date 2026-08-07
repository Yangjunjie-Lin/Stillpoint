import time

from fastapi.testclient import TestClient

from app.auth import SessionTokenService
from app.config import Settings
from app.main import create_app
from app.repository import InMemoryRepository
from app.service import NpcCognitionService


SETTINGS = Settings(app_env="test", npc_mind_signing_key="test-signing-key")


def _client():
    service = NpcCognitionService(settings=SETTINGS, repository=InMemoryRepository())
    return TestClient(create_app(service)), service


def _token(player="p", save="w", now=None):
    token, _ = SessionTokenService(SETTINGS).issue(player, save, "install-1234", now=now)
    return {"Authorization": f"Bearer {token}", "X-Client-Install-ID": "install-1234"}


def test_missing_auth_rejected():
    client, _ = _client()
    assert client.get("/v1/npcs/mira-1/memories").status_code == 401


def test_missing_client_install_id_rejected():
    client, _ = _client()
    headers = _token()
    headers.pop("X-Client-Install-ID")
    response = client.get("/v1/npcs/mira-1/memories", headers=headers)
    assert response.status_code == 401
    assert response.json()["detail"] == "missing_client_install_id"


def test_wrong_player_scope_rejected():
    client, _ = _client()
    response = client.get(
        "/v1/npcs/mira-1/memories?player_profile_id=other", headers=_token()
    )
    assert response.status_code == 403


def test_expired_token_rejected():
    client, _ = _client()
    response = client.get(
        "/v1/npcs/mira-1/memories", headers=_token(now=int(time.time()) - 10000)
    )
    assert response.status_code == 401
    assert response.json()["detail"] == "expired_token"


def test_export_requires_owner():
    client, _ = _client()
    assert client.get("/v1/players/other/npc-memories/export", headers=_token()).status_code == 403
    assert client.get("/v1/players/p/npc-memories/export", headers=_token()).status_code == 200


def test_delete_requires_owner():
    client, _ = _client()
    assert client.delete("/v1/players/other/npc-memories", headers=_token()).status_code == 403
    assert client.delete("/v1/players/p/npc-memories", headers=_token()).status_code == 200
