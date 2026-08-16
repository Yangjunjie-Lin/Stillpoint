# Simulation Authority

## Non-negotiable rule

**The LLM is not the world authority.**

An LLM, NPC Mind endpoint, PostgreSQL row, memory, belief edge, dialogue line,
or `IntentProposal` cannot directly change canonical gameplay state. Only
Godot simulation handlers operating on current trusted state may commit a
change.

## Ownership matrix

| Layer | Owns | Must not own |
| --- | --- | --- |
| Godot simulation | Canonical gameplay state, rules, validation, execution, authoritative time, events | Provider credentials; model-authored facts accepted without rules |
| Save v4+ | Canonical local persistence and per-region snapshots | Model prompts or a second copy of mutable gameplay truth |
| NPC Mind backend | Scoped sessions, memories, beliefs, semantic retrieval, candidate graph updates, usage/idempotency | Inventory, balances, equipment, health, faction/territory ownership, quest completion |
| PostgreSQL/pgvector | Durable backend cognitive data and backend operational records | Canonical local gameplay state |
| LLM provider | Optional reply/reasoning candidate within a strict schema | Execution, SQL access, direct calls to Godot mutators |

## Typed intent contract

0.9.0 introduces:

- `WorldIntent`: data-only typed request base;
- `TalkIntent`: the single harmless pilot;
- `IntentProposal`: proposal ID, source kind, proposer identity, and intent;
- `IntentValidationResult`: allow/reject result with stable reason code;
- `WorldIntentValidator`: pure current-state and authorization checks;
- `WorldIntentExecutor`: trusted dispatch, mutation, and event emission.

The pilot path is:

```text
NPCInteractable + verified player input
→ IntentProposal(source=player_input, TalkIntent)
→ validate actor, target identity, source, region, range, and talk policy
→ evaluate read-only authored Conditions
→ FINAL AUTHORIZATION (consume proposal ID for this session)
→ apply trusted authored Effects
→ start deterministic dialogue
→ emit NPC_TALKED with proposal provenance
```

`NPCInteractable` only resolves identities, creates the proposal, delegates its
authored Conditions/Effects to `WorldSession.submit_interaction_intent()`, and
displays a rejection notice. `WorldIntentExecutor` owns ordering. It never runs
the ordinary validator after Effects begin, so an Effect which changes range or
NPC state cannot make the transaction reject itself after a partial commit.

In 0.9.0, `TalkIntent` from `LLM`, `DETERMINISTIC_AI`, or `SYSTEM` is rejected.
Provider `proposed_intents` remain audit-only and are not converted or submitted
by the client. This deliberate narrowness proves the boundary without enabling
new autonomous gameplay.

## Interaction failure and replay semantics

`WorldEffect.apply_sequence()` does not provide rollback. A failed required
Effect stops the sequence and prevents dialogue and `NPC_TALKED`, but successful
earlier Effects remain committed. A dialogue-start failure likewise emits no
`NPC_TALKED`; Effects which already succeeded remain committed. 0.9.0 documents
and tests this behavior instead of claiming a general transaction framework.

After validation and Conditions succeed, the executor records the proposal ID
in a session-local consumed set before applying Effects. Replaying that ID in
the same session is rejected before any Effect, even if different authored
metadata is supplied. This guard is deliberately not persisted: `proposal_id`
remains provenance, not durable exactly-once transaction storage. Persistent
idempotency for financial, work, equipment, and governance intents belongs to
0.11.0.

## Existing trusted mutation paths

Typed intents do not replace every mature command path in this milestone.
These existing deterministic owners remain authoritative:

| State | Current mutation owner |
| --- | --- |
| Health/death/knockback | Combat pipeline through `Hurtbox3D`, `CombatComponent`, `HealthComponent`, and actor controllers |
| Inventory/equipment | `InventoryComponent`, `InventoryTransferService`, `EquipmentComponent`, validated interactables/effects |
| Player funds/property | `PropertyBankService` and `CommerceService` |
| Farming | `FarmPlot` plus authoritative world day and player components |
| Quest lifecycle | `QuestCoordinator` over `QuestManager`, Conditions, and required/retryable Effects |
| Relationships | `RelationshipService` via its component facade and effects |
| World flags | `WorldFlagService` via trusted Effects |
| Region travel/spawn/destruction | `WorldSession`, `RegionRuntimeService`, `ActorFactory`, repository, and typed Effects |
| Dungeon progression/loot | `DungeonProgressionService` and authored loot tables |
| Pet state/behavior | `PetRuntimeState`, deterministic pet behavior/runtime services |

`WorldEffect` is a trusted authored command, not an AI tool. Conditions are
read-only; coordinators own transaction ordering and required failure behavior.
Future AI-facing actions must go through typed intents and may call these same
domain services only after validation.

## Adding an intent safely

An intent is incomplete until all of the following exist:

1. a bounded typed payload containing IDs and quantities, never Nodes or
   callbacks;
2. an explicit source policy;
3. validation of actor identity, target, permission, availability, resources,
   state, capacity, and replay/idempotency where relevant;
4. a simulation-owned handler that reuses existing domain services;
5. a `GameplayEvent` emitted only after success;
6. persistence/dirty marking for every changed canonical section;
7. tests proving forged, stale, impossible, duplicate, and LLM-sourced requests
   cannot mutate state.

Never add an `execute()`, `apply()`, world reference, SQL client, or arbitrary
callable to an intent data object.
