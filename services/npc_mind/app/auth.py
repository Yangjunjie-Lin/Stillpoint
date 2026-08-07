from __future__ import annotations

import base64
import hashlib
import hmac
import json
import ipaddress
import time
from dataclasses import dataclass
from typing import Any

from .config import Settings


@dataclass(frozen=True, slots=True)
class SessionClaims:
    player_profile_id: str
    world_save_id: str
    client_install_id: str
    expires_at: int


class SessionTokenService:
    def __init__(self, settings: Settings) -> None:
        self._key = settings.npc_mind_signing_key.encode("utf-8")
        self._ttl = settings.session_token_ttl_seconds

    def issue(
        self,
        player_profile_id: str,
        world_save_id: str,
        client_install_id: str,
        *,
        now: int | None = None,
    ) -> tuple[str, int]:
        if not self._key:
            raise RuntimeError("signing_key_not_configured")
        if not player_profile_id or not world_save_id or not client_install_id:
            raise ValueError("invalid_session_scope")
        issued_at = int(time.time() if now is None else now)
        expires_at = issued_at + self._ttl
        payload = {
            "player_profile_id": player_profile_id,
            "world_save_id": world_save_id,
            "client_install_id": client_install_id,
            "issued_at": issued_at,
            "expires_at": expires_at,
        }
        encoded = _encode(json.dumps(payload, separators=(",", ":"), sort_keys=True).encode())
        signature = _encode(hmac.new(self._key, encoded.encode(), hashlib.sha256).digest())
        return f"{encoded}.{signature}", expires_at

    def verify(
        self,
        token: str,
        *,
        client_install_id: str = "",
        now: int | None = None,
    ) -> SessionClaims:
        if not self._key:
            raise RuntimeError("signing_key_not_configured")
        try:
            encoded, supplied_signature = token.split(".", 1)
            expected = _encode(hmac.new(self._key, encoded.encode(), hashlib.sha256).digest())
            if not hmac.compare_digest(expected, supplied_signature):
                raise ValueError("invalid_token")
            payload: dict[str, Any] = json.loads(_decode(encoded))
            claims = SessionClaims(
                player_profile_id=str(payload["player_profile_id"]),
                world_save_id=str(payload["world_save_id"]),
                client_install_id=str(payload["client_install_id"]),
                expires_at=int(payload["expires_at"]),
            )
        except (KeyError, TypeError, ValueError, json.JSONDecodeError) as exc:
            raise ValueError("invalid_token") from exc
        current = int(time.time() if now is None else now)
        if claims.expires_at <= current:
            raise ValueError("expired_token")
        if client_install_id and not hmac.compare_digest(
            claims.client_install_id, client_install_id
        ):
            raise ValueError("client_install_mismatch")
        return claims


class ClientAuthenticator:
    """Authorize token issuance without treating a client-supplied scope as proof."""

    def __init__(self, settings: Settings) -> None:
        settings.validate_auth_mode()
        self._mode = settings.auth_mode
        self._clients: dict[str, Any] = {}
        if self._mode == "paired_client":
            try:
                parsed = json.loads(settings.paired_client_credentials_json)
            except (TypeError, json.JSONDecodeError) as exc:
                raise ValueError("paired_client_registry_invalid") from exc
            if not isinstance(parsed, dict):
                raise ValueError("paired_client_registry_invalid")
            _validate_paired_registry(parsed)
            self._clients = parsed

    def authorize_issue(
        self,
        *,
        client_host: str,
        header_client_install_id: str,
        client_secret: str,
        player_profile_id: str,
        world_save_id: str,
        requested_client_install_id: str,
    ) -> None:
        if not header_client_install_id or not hmac.compare_digest(
            header_client_install_id, requested_client_install_id
        ):
            raise ValueError("client_install_mismatch")
        if self._mode == "local_loopback":
            if not _is_loopback(client_host):
                raise ValueError("loopback_source_required")
            return

        if not client_secret:
            raise ValueError("paired_client_credentials_required")
        credential = self._clients.get(requested_client_install_id)
        if not isinstance(credential, dict):
            raise ValueError("invalid_client_credentials")
        expected_hash = str(credential.get("secret_sha256", "")).lower()
        supplied_hash = hashlib.sha256(client_secret.encode("utf-8")).hexdigest()
        if len(expected_hash) != 64 or not hmac.compare_digest(expected_hash, supplied_hash):
            raise ValueError("invalid_client_credentials")
        scopes = credential.get("scopes", [])
        authorized = any(
            isinstance(scope, dict)
            and hmac.compare_digest(str(scope.get("player_profile_id", "")), player_profile_id)
            and hmac.compare_digest(str(scope.get("world_save_id", "")), world_save_id)
            for scope in scopes
        )
        if not authorized:
            raise ValueError("client_scope_not_authorized")


def _encode(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode("ascii")


def _decode(value: str) -> bytes:
    padding = "=" * (-len(value) % 4)
    return base64.urlsafe_b64decode(value + padding)


def _is_loopback(host: str) -> bool:
    try:
        return ipaddress.ip_address(host).is_loopback
    except ValueError:
        return False


def _validate_paired_registry(registry: dict[str, Any]) -> None:
    for install_id, credential in registry.items():
        if not install_id or not isinstance(credential, dict):
            raise ValueError("paired_client_registry_invalid")
        if any(key in credential for key in ("secret", "client_secret", "raw_secret")):
            raise ValueError("paired_client_registry_contains_raw_secret")
        secret_hash = str(credential.get("secret_sha256", ""))
        if len(secret_hash) != 64 or any(character not in "0123456789abcdef" for character in secret_hash):
            raise ValueError("paired_client_registry_invalid")
        scopes = credential.get("scopes")
        if not isinstance(scopes, list) or not scopes:
            raise ValueError("paired_client_registry_invalid")
        if any(
            not isinstance(scope, dict)
            or not str(scope.get("player_profile_id", ""))
            or not str(scope.get("world_save_id", ""))
            for scope in scopes
        ):
            raise ValueError("paired_client_registry_invalid")
