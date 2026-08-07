import base64
import hashlib
import json

import pytest
from fastapi.testclient import TestClient

from app.auth import ClientAuthenticator, SessionTokenService
from app.config import Settings
from app.main import create_app
from app.repository import InMemoryRepository
from app.service import NpcCognitionService


def _paired_settings() -> tuple[Settings, str]:
    secret = "paired-client-test-secret"
    registry = {
        "install-1234": {
            "secret_sha256": hashlib.sha256(secret.encode()).hexdigest(),
            "scopes": [{"player_profile_id": "player", "world_save_id": "save"}],
        }
    }
    return (
        Settings(
            app_env="test",
            auth_mode="paired_client",
            paired_client_credentials_json=json.dumps(registry),
            npc_mind_signing_key="session-boundary-test-key",
        ),
        secret,
    )


def _session_payload() -> dict[str, str]:
    return {
        "player_profile_id": "player",
        "world_save_id": "save",
        "client_install_id": "install-1234",
    }


def test_remote_auth_requires_paired_client():
    settings = Settings(app_env="test", npc_mind_signing_key="loopback-test-key")
    service = NpcCognitionService(settings=settings, repository=InMemoryRepository())
    response = TestClient(create_app(service)).post(
        "/v1/auth/session",
        headers={"X-Client-Install-ID": "install-1234"},
        json=_session_payload(),
    )
    assert response.status_code == 403
    assert response.json()["detail"] == "loopback_source_required"


def test_loopback_auth_rejects_non_loopback():
    authenticator = ClientAuthenticator(Settings(app_env="test"))
    with pytest.raises(ValueError, match="loopback_source_required"):
        authenticator.authorize_issue(
            client_host="203.0.113.50",
            header_client_install_id="install-1234",
            client_secret="",
            player_profile_id="player",
            world_save_id="save",
            requested_client_install_id="install-1234",
        )


def test_client_install_id_alone_is_not_remote_auth():
    settings, _ = _paired_settings()
    service = NpcCognitionService(settings=settings, repository=InMemoryRepository())
    response = TestClient(create_app(service)).post(
        "/v1/auth/session",
        headers={"X-Client-Install-ID": "install-1234"},
        json=_session_payload(),
    )
    assert response.status_code == 401
    assert response.json()["detail"] == "paired_client_credentials_required"


def test_paired_client_cannot_issue_an_unregistered_scope():
    settings, secret = _paired_settings()
    service = NpcCognitionService(settings=settings, repository=InMemoryRepository())
    payload = _session_payload()
    payload["world_save_id"] = "other-save"
    response = TestClient(create_app(service)).post(
        "/v1/auth/session",
        headers={
            "X-Client-Install-ID": "install-1234",
            "X-Client-Secret": secret,
        },
        json=payload,
    )
    assert response.status_code == 403
    assert response.json()["detail"] == "client_scope_not_authorized"


def test_paired_registry_rejects_raw_client_secret():
    with pytest.raises(ValueError, match="paired_client_registry_contains_raw_secret"):
        ClientAuthenticator(
            Settings(
                app_env="test",
                auth_mode="paired_client",
                paired_client_credentials_json=json.dumps(
                    {
                        "install-1234": {
                            "secret": "must-not-be-stored",
                            "secret_sha256": "0" * 64,
                            "scopes": [
                                {"player_profile_id": "player", "world_save_id": "save"}
                            ],
                        }
                    }
                ),
            )
        )


def test_token_scope_cannot_be_changed_after_issue():
    settings, _ = _paired_settings()
    token, _ = SessionTokenService(settings).issue("player", "save", "install-1234")
    encoded, signature = token.split(".", 1)
    padding = "=" * (-len(encoded) % 4)
    payload = json.loads(base64.urlsafe_b64decode(encoded + padding))
    payload["world_save_id"] = "other-save"
    changed = base64.urlsafe_b64encode(
        json.dumps(payload, separators=(",", ":"), sort_keys=True).encode()
    ).rstrip(b"=").decode()
    service = NpcCognitionService(settings=settings, repository=InMemoryRepository())
    response = TestClient(create_app(service)).get(
        "/v1/npcs/mira-1/memories",
        headers={
            "Authorization": f"Bearer {changed}.{signature}",
            "X-Client-Install-ID": "install-1234",
        },
    )
    assert response.status_code == 401
    assert response.json()["detail"] == "invalid_token"
