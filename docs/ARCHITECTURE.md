# Architecture (Godot 0.11.0)

Runnable **Vertical Slice** via **WorldSession** + **Combat Lab** on **Jolt Physics**. See [WORLD_ARCHITECTURE.md](WORLD_ARCHITECTURE.md) for the world service split, Save v4, and region dynamic loading. Version 0.11.0 retains the action-camera/combat foundation and adds shared actor economics while preserving the typed-intent authority boundary documented in [SIMULATION_AUTHORITY.md](SIMULATION_AUTHORITY.md).

## Simulation Authority

`WorldSession` owns a `WorldIntentValidator` and `WorldIntentExecutor`. Intents
are data only. `TalkIntent` accepts verified player input. NPC `WorkIntent`,
`PurchaseIntent`, and `EquipIntent` accept only actor-scoped
`DETERMINISTIC_AI`, validate a durable per-actor next sequence, and commit via
`ActorEconomyService`. LLM-attributed proposals are rejected and provider
intent arrays remain unexecuted.

## Shared Actor Economy

`CharacterController` exposes shared `WalletComponent`, `InventoryComponent`,
`EquipmentComponent`, `SkillComponent`, `EnergyComponent`,
`ActorAttributesComponent`, and optional `EmploymentComponent` capabilities.
The player and NPCs use the same wallet, inventory, equipment, item metadata,
and commerce transaction core.

`PropertyBankService` owns bank deposits, home cash, investments, property, and
custodial storage. It delegates carried money to the player's
`WalletComponent`; its `wallet_balance` property is a compatibility adapter,
not a second balance. Property section v3 omits pocket money. Old section v1/v2
`wallet_balance` imports once into the player wallet; subsequent saves persist
the wallet in `player.json` while retaining Save major version 4.

`JobDefinition` and `WorkSiteDefinition` are immutable authored resources.
`EmploymentContract`, `EmploymentComponent`, `WorkSiteRuntimeState`, and
`WorkResult` are per-instance runtime data. `ActorEconomyService` persists
finite worksite payroll in the global-world section; actor component state is
captured by `EntitySnapshot`. `WorkService` uses a deterministic bounded
formula over skill, attributes, equipped tool metadata, energy, and workplace
efficiency. Paid work atomically debits payroll and credits the worker wallet.

The current vertical slice intentionally stops at abstract work units. Business
inventory, material production, revenue, scarcity, and dynamic prices remain
0.12.0 scope.

## Jolt Physics Foundation

Project explicitly sets `physics/3d/physics_engine="Jolt Physics"`, 60 TPS, physics interpolation, single-threaded physics for deterministic tests. `PhysicsSettingsService` verifies backend at boot.

Characters stay on `CharacterBody3D`; props use `RigidBody3D` / `StaticBody3D`.

## Combat Animation Pipeline

```text
Input → CombatComponent.request_attack()
→ CombatAnimationController (AnimationPlayer events)
→ open/close attack & combo windows
→ Hitbox3D + MeleeSweep3D
→ unified damage pipeline
→ KnockbackComponent / HitStopController / CombatFeedbackController
```

Attack timing is **animation-event driven**; timers are watchdog-only.

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

`CameraController3D` is a presentation/control context, not a player entity. A
single yaw/pitch rig owns one active `Camera3D` and exposes perspective,
collision, free-aim, and settings APIs. `TargetingComponent3D` owns candidate
selection and lock invalidation; it does not mutate world state.

`CombatComponent.CombatState` owns detailed timing (`READY`, `WINDUP`, `ACTIVE`,
`RECOVERY`, `PARRY_WINDOW`, `GUARDING`, `DODGING`, `BLOCKSTUN`, `HITSTUN`,
`STAGGERED`, `KNOCKED_DOWN`, `DISABLED`). `CharacterState` remains the coarse
actor availability state. Dodge movement/iframes, guard/parry resolution,
poise, and stun are simulation-owned; animation is presentation and event
timing only. The root-motion policy for 0.10.0 is simulation-authoritative
locomotion and attack displacement.

## Single-source Relationship Model

`RelationshipService` is the only persistent store (`affinity`, `temporary_hostile`, `anger`).

`RelationshipComponent` is a facade bound to its owner character.

Defaults from `CharacterDefinition.default_disposition`: friendly=60, neutral=0, hostile=-30.

Rules: friendly attacks lower affinity plus a 10-second aggression refusal; affinity &lt; 50 → neutral; neutral first hit → hostile; hostile fights without friendly penalties. The affinity/anger loss persists, while aggression-created temporary hostility expires from its saved timestamp.

## NPC Downed / Death

`can_be_killed = false` → DOWNED at 1 HP (Mira/Ren).  
`can_be_killed = true` → permanent death / queue_free (Bandit).

## Region Runtime Lifecycle

`WorldSession` delegates region ownership to `RegionRuntimeService`. Exactly one region scene is loaded in `ActiveRegionSlot`; Player, Pet, and Mount remain under `PersistentRoot`. Leaving a region captures its live entity snapshots before freeing the region root.

Load order is: instantiate region → register static identities → hydrate the region chunk → restore static state → process authored spawn markers → materialize queued runtime snapshots → register interactables → place persistent actors. Runtime actors are parented to `DynamicEntities`.

## Dialogue UI Flow

`DialogueRunner` → EventBus → `DialogueUI` (speaker, body, choice buttons, 1–9 keys) → `DialogueCoordinator.apply_choice`. A failed required choice effect leaves the current node and dialogue open and emits `choice_effect_failed`.

## Quest Objective Flow

Ordered objectives use `QuestRuntime.current_objective_index`. Required lifecycle effects must succeed before their corresponding progress/claim flags are committed. Stable applied-effect IDs prevent already successful rewards from replaying when a later required reward is repaired and retried.

## World Save v4

Save v4 uses a validated manifest, critical section files, and per-region chunks. Continue rejects a future manifest or an invalid Player section, can use manifest/player backups, and treats a missing or corrupt optional global-world section as a warned default. Restore failure disables input/autosave, unloads partial region state, and returns to the menu without writing over the source save.

The v3 importer converts legacy NPC state to `components.character`, Chest state to `components.chest`, and Pickup state to `components.pickup` before starting the restored `WorldSession`.

## Pet and Mount Persistence

Real PetController/MountController state serialized (bond, mode, position, region). Mount uses toggle walk/run state, not held Space.

## Async Integration Tests

`tests/test_runner.gd` discovers all unit and integration scripts, awaits coroutines, resets autoload state between tests, and cleans world saves. Coverage includes Jolt combat, Save v4 corruption/backup boundaries, live region transitions, runtime-spawn restart/destruction, required-effect retry, v3 instance migration, Combat Lab, Legacy Survival, and the Main Menu Continue button path.
