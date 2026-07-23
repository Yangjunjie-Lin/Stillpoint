# Quest, Condition & Effect Guide

## Gameplay Events

Emit facts via `GameplayEvent` / `GameplayEventBus`. Pickups emit `item_collected`; dialogue effects may emit `item_delivered`.

## Quest Lifecycle (QuestCoordinator)

1. **Start** — evaluate `start_conditions` → `QuestManager.start_quest` → apply `start_effects`
2. **Objective complete** — advance progress → apply that objective's `completion_effects`
3. **Quest complete** — apply `completion_effects` once → apply `reward_effects` once (`rewards_claimed`)
4. **Fail** — `QuestManager.fail_quest` → apply `failure_effects`

`StartQuestEffect` / lifecycle APIs go through `QuestCoordinator`. `QuestManager` owns runtime state and serialization only.

## Quest Objectives

Set `event_type`, `target_definition_id`, and optional `region_id` on `ObjectiveDefinition`. `QuestEventRouter` matches active objectives and calls the coordinator.

## Conditions

Extend `WorldCondition` and evaluate against `WorldSessionContext`. Conditions never mutate state.

## Effects

Extend `WorldEffect` and apply via `WorldEffectContext`. Chain with `WorldEffect.apply_sequence()`.

Notable production effects:

- `SpawnEntityEffect` — spawns via ActorFactory when the region is loaded; otherwise stores a snapshot for later
- `DestroyEntityEffect` — frees loaded nodes and marks snapshot `destroyed`
- `UnlockPetEffect` / `UnlockMountEffect` — record unlocked IDs on the session (no fake success)

## Demo Quest

`resources/quests/demo_errand.tres` uses event-driven objectives and `reward_effects` — no hardcoded quest IDs in core services.
