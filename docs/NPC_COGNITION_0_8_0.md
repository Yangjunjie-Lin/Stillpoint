# Stillpoint 0.8.0 NPC Cognitive Foundation

Stillpoint 0.8.0 adds an authored NPC mind profile and an application-owned
cognition service. It does not add 3D models, animation assets, or a second
gameplay/quest system.

## Ownership and boundaries

Godot talks only to the Stillpoint-owned backend:

```text
Godot NPCDialogueGateway → Stillpoint NPC Mind Backend → configured provider
```

Provider credentials are read by the backend from environment/secret-manager
configuration. They are never stored in GDScript, resources, scenes, export
presets, client settings, or Save v4. CI uses `FakeLlmProvider` and
`FakeEmbeddingProvider`.

The model can return reply text, emotion, animation id, memory candidates,
graph candidates, and proposed intents. The first 0.8.0 slice executes no
gameplay intents. Existing deterministic `DialogueRunner` remains the owner of
quest-critical dialogue and all WorldEffects.

## Authored ontology

`NPCDefinition` identifies a reusable archetype. Its `mind_profile` is an
authoritative `.tres` resource containing structured identity, personality,
speech style, biography, goals, knowledge/belief seeds, cognitive skills, and
memory policy. The catalog exporter derives
`services/npc_mind/catalog/generated_npc_catalog.json`; the JSON is a deployment
artifact and is never edited independently.

`NPCDefinition.id` and a runtime persistent id are separate. Runtime cognition
is isolated by the tuple `(player_profile_id, world_save_id,
npc_persistent_id)`, so `bandit_0001` and `bandit_0002` never share memories and
different players cannot see one another's data.

Gameplay `SkillDefinition` is intentionally separate from
`NPCCognitiveSkillDefinition`. Cognitive skills carry domain, proficiency,
knowledge references, explicit tools, and response constraints.

## Graph and memory

PostgreSQL is the production-default repository and stores sessions, turns,
memories, recall history, idempotency responses, usage, profile deployment
revisions, graph data, sync revisions, outbox receipts, and conflicts. The
`vector` extension is installed by Alembic and every retrieval embeds the live
query before running a scope-filtered pgvector cosine search. In-memory storage
is available only when both `APP_ENV=test` and `NPC_REPOSITORY=in_memory` are
explicitly configured; connection failure never falls back silently.
Canonical facts use a null graph owner; NPC beliefs use the NPC persistent id.
Memory retrieval filters the full player/save/NPC scope. Prompt graph traversal
starts from the NPC instance and currently visible entity ids and is bounded to
two hops; graph API node results are limited to nodes referenced by the scoped,
visible edge result. It never returns the database's complete node table.

Memory records retain source ids, salience, confidence, embeddings, recall
history, and optional supersession. Recency uses:

```text
exp(-ln(2) × age_hours / half_life_hours)
```

Semantic, salience, goal, graph, relationship, recency, and reinforcement
signals are combined in the backend policy. Successful recall updates
`last_recalled_at`, `recall_count`, and bounded `retention_strength`; old
evidence is not deleted solely for being old. Conversation turns roll into a
summary while raw authoritative records remain persisted.

## Save and offline behavior

`NPCCognitionSaveProvider` adds optional Save v4 section `npc_cognition` at
section version 1. A 0.7.1 Save v4 without this section restores an empty cache
without migration. Local data includes session index, compact cache, pending
event/turn outboxes, sync revision, and conflicts. Backend timeout, invalid
JSON, rate limiting, or disabled AI restores deterministic dialogue and never
blocks quests, trade, combat, transition, save, or Continue.

Players can disable AI, conversation storage, or personalization; the backend
exposes deletion and export endpoints for NPC-scoped and player-scoped data.

## Local development

The development transport is plain HTTP on loopback; production TLS belongs at
the reverse proxy, ingress, or deployment platform:

```text
Godot NPC_BACKEND_URL=http://127.0.0.1:8443
Docker/PostgreSQL host port=55432
Backend container PostgreSQL port=5432
Production NPC_BACKEND_URL=https://...
```

From `services/npc_mind`:

```bash
docker compose up -d postgres
DATABASE_URL=postgresql+psycopg://stillpoint:stillpoint@127.0.0.1:55432/stillpoint alembic -c alembic.ini upgrade head
uvicorn app.main:app --host 127.0.0.1 --port 8443
```

The client first requests a short-lived HMAC-signed session token. The token is
bound to player profile, world save, client installation, and expiry. Every
conversation, memory, graph, sync, export, and deletion route enforces that
scope. `NPC_MIND_SIGNING_KEY` and provider credentials remain backend-only and
the export presets exclude backend, test, tool, artifact, and build trees.
