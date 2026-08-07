from __future__ import annotations

import base64
import hashlib
import hmac
import json
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


def _encode(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode("ascii")


def _decode(value: str) -> bytes:
    padding = "=" * (-len(value) % 4)
    return base64.urlsafe_b64decode(value + padding)
