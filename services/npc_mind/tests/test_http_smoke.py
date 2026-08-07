import hashlib
import json

from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app
from app.repository import InMemoryRepository
from app.service import NpcCognitionService


def test_local_http_health_and_session_token_smoke():
    client_secret = "smoke-client-secret"
    settings = Settings(
        app_env="test",
        auth_mode="paired_client",
        paired_client_credentials_json=json.dumps(
            {
                "smoke-install": {
                    "secret_sha256": hashlib.sha256(client_secret.encode()).hexdigest(),
                    "scopes": [
                        {
                            "player_profile_id": "smoke-player",
                            "world_save_id": "smoke-save",
                        }
                    ],
                }
            }
        ),
        npc_repository="in_memory",
        npc_mind_signing_key="smoke-test-signing-key",
    )
    service = NpcCognitionService(settings=settings, repository=InMemoryRepository())
    with TestClient(create_app(service)) as client:
        health = client.get("/health")
        token = client.post(
            "/v1/auth/session",
            headers={
                "X-Client-Install-ID": "smoke-install",
                "X-Client-Secret": client_secret,
            },
            json={
                "player_profile_id": "smoke-player",
                "world_save_id": "smoke-save",
                "client_install_id": "smoke-install",
            },
        )
    assert health.status_code == 200
    assert health.json()["repository"] == "InMemoryRepository"
    assert token.status_code == 200
    assert token.json()["token_type"] == "Bearer"
    assert token.json()["token"]
