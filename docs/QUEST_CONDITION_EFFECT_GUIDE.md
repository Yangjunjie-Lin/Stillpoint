# Quest, Condition & Effect Guide

## Gameplay Events

Emit facts via `GameplayEvent` / `GameplayEventBus`. Pickups emit `item_collected`; dialogue effects may emit `item_delivered`.

## Quest Objectives

Set `event_type`, `target_definition_id`, and optional `region_id` on `ObjectiveDefinition`. `QuestEventRouter` matches active objectives automatically.

## Conditions

Extend `WorldCondition` and evaluate against `WorldSessionContext`. Conditions never mutate state.

## Effects

Extend `WorldEffect` and apply via `WorldEffectContext`. Chain with `WorldEffect.apply_sequence()`.

## Demo Quest

`resources/quests/demo_errand.tres` uses event-driven objectives and `reward_effects` for gift box and affinity — no hardcoded quest logic in core services.
