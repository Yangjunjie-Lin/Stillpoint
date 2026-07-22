# Architecture (Godot 0.5.1)

Runnable **Vertical Slice** for the isekai life-sim RPG foundation. Legacy 2D survival remains under `scenes/gameplay/`.

## Unified Damage Pipeline

```text
Hitbox3D (active frames only, per-target once)
→ Hurtbox3D
→ CharacterController.receive_damage()
→ CombatComponent.resolve_incoming_damage()  # Guard / energy
→ HealthComponent.apply_damage()
→ NPC aggression / downed / death
```

Hurtboxes never call Health directly. Guard applies only for frontal blocked hits with enough energy.

## Single-source Relationship Model

`RelationshipService` is the only persistent store (`affinity`, `temporary_hostile`, `anger`).

`RelationshipComponent` is a facade bound to its owner character.

Defaults from `CharacterDefinition.default_disposition`: friendly=60, neutral=0, hostile=-30.

Rules: friendly attacks lower affinity + temporary refusal; affinity &lt; 50 → neutral; neutral first hit → hostile; hostile fights without friendly penalties.

## NPC Downed / Death

`can_be_killed = false` → DOWNED at 1 HP (Mira/Ren).  
`can_be_killed = true` → permanent death / queue_free (Bandit).

## Region Activation Lifecycle

`WorldManager._set_region_active` toggles `visible`, `process_mode`, collision layers/masks, Area monitoring, and `CollisionShape3D.disabled`. Hidden regions do not collide or interact.

## Dialogue UI Flow

`DialogueRunner` → EventBus → `DialogueUI` (speaker, body, choice buttons, 1–9 keys) → `WorldManager.apply_dialogue_choice`.

## Quest Objective Flow

Ordered objectives via `QuestRuntime.current_objective_index`. Demo: Talk → Collect → Deliver.

## World Save v3

Sections: profile, player, world, relationships, quests, inventory, pets, mounts, npcs, interactables, regions. Inventory lives at top-level only. Future versions rejected.

## Pet and Mount Persistence

Real PetController/MountController state serialized (bond, mode, position, region). Mount uses toggle walk/run state, not held Space.

## Async Integration Tests

`tests/test_runner.gd` awaits coroutines, resets autoload state between tests, and cleans world saves.
