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

OpenAI-compatible text providers use `OPENAI_BASE_URL`, `OPENAI_API_KEY`, and
`OPENAI_TEXT_MODEL`. External base URLs must use HTTPS. Text and embedding providers are
configured independently: set `NPC_EMBEDDING_PROVIDER=fake` when an OpenAI-compatible text
provider does not offer a schema-compatible 1536-dimensional embedding model. This preserves
the database contract without truncating or padding vectors.

`OPENAI_RESPONSE_FORMAT` defaults to `json_object`. Set it to `json_schema` only for a
compatible endpoint that supports schema-constrained responses; the result still passes through
the same Pydantic and gameplay-boundary validation. For compatible models that do not reliably
emit the structured contract (for example SiliconFlow Qwen 7B), `text` mode asks the provider
for only the spoken reply and fills safe server-owned defaults for emotion and candidate arrays;
it never accepts model-authored memory, graph, or gameplay intents.

Pet movement personality assessment is a low-frequency advisory use of the configured text
provider. The server caches it by Player/Save/persistent pet plus normalized mood, region,
lifestyle, individual traits, and the server-owned catalog profile revision. Client request IDs
and context revisions cannot force another paid call. `NPC_PET_MOVEMENT_ASSESSMENT_COOLDOWN_SECONDS`
defaults to 60 seconds per pet, and `NPC_PET_MOVEMENT_PLAYER_RATE_PER_MINUTE` defaults to 6. The
shared `NPC_DAILY_BUDGET_USD` is checked before every paid assessment; successful or failed
provider attempts are conservatively recorded in the usage ledger. A denied, timed-out, or
invalid assessment falls back to deterministic local movement weights and never writes a
conversation, memory, graph edge, gameplay intent, or outbox event.

For SiliconFlow and other OpenAI-compatible models that are more reliable in plain text than
JSON mode, movement assessment uses a deliberately tiny, strict one-line protocol. The model
must return exactly one line in this form (an optional final Chinese full stop is accepted):

```text
动作=守候|跟随|探索|玩耍|亲近|巡逻|观察|休息;节奏=慢|中|快;范围=近|中|远
```

For example: `动作=观察;节奏=中;范围=近。`. The service maps those three fields to its
allowlisted movement motifs and bounded pace/roam preference. It rejects extra prose, unknown
fields, coordinates, targets, attacks, teleports, and duplicate separators. One corrective
provider retry is allowed for malformed output; a second failure uses the local deterministic
policy. This protocol is advisory only: Godot still owns anchors, navigation, collision,
coordinates, and all movement execution.
