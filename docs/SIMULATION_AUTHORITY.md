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
→ start deterministic dialogue
→ emit NPC_TALKED with proposal provenance
```

In 0.9.0, `TalkIntent` from `LLM`, `DETERMINISTIC_AI`, or `SYSTEM` is rejected.
Provider `proposed_intents` remain audit-only and are not converted or submitted
by the client. This deliberate narrowness proves the boundary without enabling
new autonomous gameplay.

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
