import hashlib
import json

from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app
from app.repository import InMemoryRepository
from app.service import NpcCognitionService


def test_world_persistent_id_session_reaches_turn_route():
    secret = "path-route-client-secret"
    settings = Settings(
        app_env="test",
        auth_mode="paired_client",
        paired_client_credentials_json=json.dumps(
            {
                "install-1234": {
                    "secret_sha256": hashlib.sha256(secret.encode()).hexdigest(),
                    "scopes": [{"player_profile_id": "player", "world_save_id": "slot-01"}],
                }
            }
        ),
        npc_mind_signing_key="path-route-signing-key",
    )
    client = TestClient(
        create_app(NpcCognitionService(settings=settings, repository=InMemoryRepository()))
    )
    auth = client.post(
        "/v1/auth/session",
        headers={"X-Client-Install-ID": "install-1234", "X-Client-Secret": secret},
        json={
            "player_profile_id": "player",
            "world_save_id": "slot-01",
            "client_install_id": "install-1234",
        },
    )
    headers = {
        "Authorization": f"Bearer {auth.json()['token']}",
        "X-Client-Install-ID": "install-1234",
    }
    session_id = "base:town/npc/mira/session"
    response = client.post(
        f"/v1/conversations/{session_id}/turns",
        headers=headers,
        json={
            "request_id": "path-route-request",
            "player_profile_id": "player",
            "world_save_id": "slot-01",
            "npc_definition_id": "mira",
            "npc_persistent_id": "base:town/npc/mira",
            "session_id": session_id,
            "text": "Hello Mira",
        },
    )
    fetched = client.get(
        f"/v1/conversations/{session_id}",
        headers=headers,
        params={"npc_persistent_id": "base:town/npc/mira"},
    )
    wrong_npc = client.get(
        f"/v1/conversations/{session_id}",
        headers=headers,
        params={"npc_persistent_id": "base:town/npc/ren"},
    )

    assert response.status_code == 200
    assert fetched.status_code == 200
    assert fetched.json()["session_id"] == session_id
    assert wrong_npc.status_code == 404
