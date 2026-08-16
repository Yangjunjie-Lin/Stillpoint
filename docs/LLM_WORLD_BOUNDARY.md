# LLM / World Boundary

## Boundary statement

The LLM may reason and express. It may not assert or mutate canonical gameplay
state. Godot is the only gameplay authority; the Stillpoint-owned NPC Mind
backend is the only client-facing cognition service; provider credentials and
provider calls stay behind that backend.

```text
Godot bounded observation
→ NPC Mind backend retrieves scoped profile/memory/belief context
→ provider returns schema-constrained candidates
→ backend validates, filters, scopes, and records permitted cognitive data
→ Godot receives dialogue/advice/proposed intents
→ deterministic fallback or typed-intent validation
→ simulation-owned execution (if supported)
```

## Permitted model output

- reply text within length and safety bounds;
- bounded emotion and presentation hints;
- memory candidates with source, visibility, confidence, and salience;
- belief/graph candidates using allowed predicates and scoped existing nodes;
- high-level proposed intents from an allowlisted schema;
- bounded pet motion motif weights, pace, and roam advice.

These are candidates. The backend may reject them, and Godot may ignore them.

## Forbidden output effects

No model output may directly:

- add, remove, transfer, buy, sell, craft, or equip an item;
- credit, debit, transfer, or invent money;
- damage, heal, kill, revive, spawn, despawn, or teleport an entity;
- start, advance, complete, fail, or reward a quest;
- set a world flag, relationship, faction, law, office, claim, or territory;
- select arbitrary coordinates, navigation paths, collision results, or combat
  targets;
- write canonical gameplay tables in PostgreSQL or Save v4;
- schedule unbounded or per-frame provider work.

A response saying "I gave you a sword" is dialogue, not a transfer.

## Current proposal behavior

The backend response schema can carry `proposed_intents` for NPC dialogue.
Godot 0.9.0 does not automatically convert or execute them. The only integrated
intent is player-input `TalkIntent`; `WorldIntentValidator` rejects the same
intent when attributed to an LLM. Pet conversation deliberately strips all
provider intents and forces its presentation animation back to `talk`.

Future LLM intent enablement requires a finite server/client mapping from
provider schema to a concrete `WorldIntent` subtype. Unknown IDs and fields are
rejected, source remains `LLM`, and the ordinary domain validator decides the
result from current state.

## Canonical facts and beliefs

The graph distinguishes canonical facts (null cognitive owner) from beliefs
owned by a persistent NPC. Visibility and graph traversal are scoped; prompts
start from the NPC and currently visible entities and never receive the full
database. Memory isolation key:

```text
(player_profile_id, world_save_id, npc_persistent_id)
```

Two instances using one `NPCDefinition` do not share memory. An NPC can believe
something false without changing the world. Canonical events enter cognition
only through observation/witness policies and carry source provenance.

## Failure and privacy

AI can be disabled. Timeout, invalid JSON, rate limits, authentication failure,
provider failure, or backend absence must fall back to deterministic dialogue
and local pet behavior without blocking combat, quests, trade, travel, save, or
Continue. Conversation storage and memory personalization are separate player
controls; deletion/export endpoints operate on scoped cognitive data.

## Review checklist for any new model capability

- Is the input an observation rather than mutable object access?
- Is output schema finite, bounded, and `extra=forbid` where authority matters?
- Are unknown actions, fields, IDs, coordinates, and non-finite numbers rejected?
- Is provider output still attributed as `LLM` at the Godot validator?
- Does validation re-read canonical state and enforce permissions/resources?
- Does only the executor emit a `GameplayEvent` after success?
- Can disabled/failed AI preserve identical gameplay correctness?
- Do tests prove the provider cannot mutate Save v4, SQL gameplay truth, money,
  inventory, equipment, combat, quests, factions, territory, or movement?
