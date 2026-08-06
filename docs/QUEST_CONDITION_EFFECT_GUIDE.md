# Quest, Condition & Effect Guide

## Gameplay Events

Emit facts via `GameplayEvent` / `GameplayEventBus`. Pickups emit `item_collected`; dialogue effects may emit `item_delivered`.

## Quest Lifecycle (QuestCoordinator)

1. **Start** — evaluate `start_conditions` → apply `start_effects` → commit the Active runtime
2. **Objective complete** — detect the threshold → apply that objective's `completion_effects` → commit finish-line progress
3. **Quest complete** — commit Completed state → apply retryable `completion_effects` → apply retryable `reward_effects`
4. **Fail** — commit Failed state → apply retryable `failure_effects`

`StartQuestEffect` / lifecycle APIs go through `QuestCoordinator`. `QuestManager` owns runtime state and serialization only.

If a required start or objective effect fails, the quest/objective commit is not made. Completion, reward, and failure flags remain false until their required sequence succeeds. `QuestRuntime.applied_effect_ids` records stable sequence/effect IDs, so retrying after a later required failure does not replay earlier successful non-idempotent rewards. A quest whose failure effects fail remains Failed; `failure_effects_applied=false` makes those effects explicitly retryable.

## Quest Objectives

Set `event_type`, `target_definition_id`, and optional `region_id` on `ObjectiveDefinition`. `QuestEventRouter` matches active objectives and calls the coordinator.

## Conditions

Extend `WorldCondition` and evaluate against `WorldSessionContext`. Conditions never mutate state. `RegionCondition` reads `context.get_current_region_id()` dynamically; `EventMatchCondition` reads `context.gameplay_event.region_id`, because event location and current world location are different facts.

## Effects

Extend `WorldEffect` and apply via `WorldEffectContext`. Chain with `WorldEffect.apply_sequence()`.

Notable production effects:

- `SpawnEntityEffect` — spawns via ActorFactory when the region is loaded; otherwise stores a snapshot for later
- `DestroyEntityEffect` — frees loaded nodes and marks snapshot `destroyed`
- `UnlockPetEffect` / `UnlockMountEffect` — record unlocked IDs on the session (no fake success)

Dialogue choice effects use the same required-result contract. A required failure emits `choice_effect_failed`, keeps the current node/dialogue open, and allows the player to retry the choice; affinity and node transition are committed only after the required sequence succeeds.

## Demo Quest

`resources/quests/demo_errand.tres` uses event-driven objectives and `reward_effects` — no hardcoded quest IDs in core services.
