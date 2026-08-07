# Stillpoint NPC Mind 0.8.0

The service has two explicit authentication modes.

`AUTH_MODE=local_loopback` is the default for the single-player local backend. Run Uvicorn
with `--host 127.0.0.1`; token issuance rejects every non-loopback source. Do not expose this
mode through a public listener or reverse proxy.

`AUTH_MODE=paired_client` is required for a remote HTTPS backend. Set
`NPC_PAIRED_CLIENT_CREDENTIALS_JSON` to a JSON object keyed by client install ID. Each entry
contains only a SHA-256 client-secret hash and an explicit list of authorized Player/Save
scopes:

```json
{
  "install-example": {
    "secret_sha256": "<64 lowercase hex characters>",
    "scopes": [
      {"player_profile_id": "player-example", "world_save_id": "slot-01"}
    ]
  }
}
```

Provision the raw client secret outside the repository and inject it into Godot with the
`NPC_CLIENT_SECRET` environment variable. The raw secret must never be placed in Save v4,
logs, exported game files, source control, or the backend registry. The backend stores and
compares only its SHA-256 hash. `X-Client-Install-ID` alone is never remote authentication.

The Godot client accepts remote URLs only over HTTPS. Loopback HTTP is limited to editor or
debug builds.

The PostgreSQL schema owns `vector(1536)`. Startup rejects any other
`NPC_EMBEDDING_DIMENSIONS` value. For OpenAI `text-embedding-3-*` models, the provider sends
`dimensions=1536` explicitly; every returned vector is checked before repository access.
