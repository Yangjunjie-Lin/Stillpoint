# World Simulation Model

## Canonical loop

Stillpoint's simulation follows one directional contract:

```text
canonical world state + actor state + actor knowledge + available actions
→ player / deterministic planner / optional LLM proposes a typed intent
→ WorldIntentValidator reads current canonical state
→ WorldIntentExecutor or another simulation-owned command handler mutates state
→ GameplayEvent records what actually happened
→ observers derive memories and beliefs
→ Save v4 persists canonical local state
```

An intent describes a desired action. A `GameplayEvent` describes a completed
fact. Neither dialogue text nor an unvalidated proposal is a fact.

## Two truths

### Canonical world truth

What actually happened: positions, health, ownership, balances, inventory,
equipment, quest state, relationships, region state, time, dungeon progress,
and future faction/economic state. Godot's deterministic simulation owns it.

### Character knowledge and belief

What an actor observed, remembers, inferred, was told, or incorrectly believes.
The NPC Mind backend may persist and retrieve this scoped cognitive state.
Canonical facts may seed cognition, but cognition does not overwrite facts.

Every observation needs provenance and visibility. An NPC does not learn an
event merely because it exists in Save v4 or PostgreSQL.

## Identity and state

- A **definition ID** identifies an authored kind, such as `mira`, `turnip`, or
  `base:town`.
- A **persistent ID** identifies one runtime world instance, such as
  `base:town/npc/mira`.
- A **snapshot** is the serialized mutable state of an unloaded instance.
- Definition resources are treated as immutable at runtime. Mutable inventory,
  money, memory, employment, equipment, ownership, and office never belong on
  a shared definition.

## Simulation levels

| Level | Intended responsibility | 0.9.0 status |
| --- | --- | --- |
| 0 — Physical | Physics, navigation, combat, animation, interaction in the active region | Implemented for the loaded slice |
| 1 — Local abstract | Nearby unloaded schedules, travel, work, transactions, basic needs | Partial hooks; pet off-screen routines exist, general NPC simulation does not |
| 2 — Regional | Hour/shift production, trade, needs, travel, relationship changes | Planned for 0.14.0 after actor economy |
| 3 — Strategic | Daily territory, policy, war, migration, and settlement development | Planned for 0.14.0 after governance |

`WorldSimulationService` currently distinguishes loaded and virtual entities,
but `tick_virtual()` is intentionally a placeholder. It must not be described
as a functioning world-scale simulator.

## Time and catch-up

`WorldTimeService` is authoritative for the playable slice. It emits minute,
hour, and day boundaries; farming, schedules, pet routines, investment
settlement, and dungeon respawn use those boundaries.

Future absence catch-up must:

- advance meaningful ticks, never replay physics frames;
- use deterministic/seeded resolution where practical;
- cap work per load and preserve a continuation cursor;
- make every aggregate change attributable to an actor, recipe, policy, or
  authored source/sink;
- never run an unbounded loop based on elapsed wall-clock time.

## Conservation contracts

### Money

Money transfers between wallets, businesses, factions, banks, treasuries, or
explicit authored sources/sinks. Current starter funds, property compensation,
and investment yield are explicit prototype sources. Fixed-price commerce does
not yet model merchant accounts or a conserved market and is therefore partial.

### Items and resources

Items originate from authored starting kits, world generation, loot tables,
harvesting, crafting/forging, or quest rewards. Transfers and equipment changes
must be atomic. Future work/production consumes declared inputs, tools, labor,
and time before producing outputs.

### Authority

Territory, employment, ownership, offices, faction membership, and quest state
change only through handlers which validate identity, permission, resources,
and current state. Narrative text cannot create these changes.

## Player/NPC symmetry rule

The target model is an `Actor` composed from shared capabilities: inventory,
equipment, wallet, stats, skills, profession, faction, property, combat, and
status effects. The current `InventoryComponent` and `EquipmentComponent`
already point in this direction. The current player-specific
`PropertyBankService` must be decomposed before NPC economic agency; adding an
independent `NPCGoldSystem` would violate this model.
