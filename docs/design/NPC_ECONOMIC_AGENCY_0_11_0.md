# NPC Economic Agency 0.11.0

## Baseline and audit

- Repository branch fetched with prune: `develop`
- Accepted baseline audited: `1a91dda13ad9b4ff2eeeeff5c9d51c45bdce82d4`
- Feature branch: `feat/0.11.0-npc-economic-agency`
- Save major: 4 (unchanged)

The audit covered the shared character/player/NPC controllers; inventory,
equipment, skill, energy, and schedule components; transfer, commerce, and
property/bank services; entity snapshots, repository, actor factory, region
runtime, typed intents, item/profession/NPC/shop definitions, all NPC scenes and
service NPC resources, blacksmith spawn/shop/building content, Save v4
coordinator/validation, and world time.

Important findings before implementation:

1. `EntitySnapshot` already discovers direct actor children that implement
   `get_persistence_key`, `capture_state`, and `restore_state`. This is the
   canonical NPC persistence extension point.
2. `InventoryComponent` and `EquipmentComponent` already provide deterministic
   operations and atomic inventory/equipment swaps; they needed actor-neutral
   documentation and snapshot hooks, not replacements.
3. `SkillComponent` already implements bounded proficiency, daily caps,
   repetition load, recovery, mastery, and persistence data suitable for
   smithing.
4. `PropertyBankService.wallet_balance` was the canonical player pocket-money
   store. `CommerceService` was typed directly to that service, though its
   inventory simulation was already atomic.
5. `NPCController` already contained `NPCState.WORK`, `ScheduleComponent`, and a
   `NavigationAgent3D`, but WORK shared wander behavior and had no bounded work
   transaction.
6. Typed intent attribution and validation existed for player `TalkIntent`, but
   proposal replay was session-local only.
7. The blacksmith already had a persistent spawn ID, shop, building, dialogue,
   and cognition profile. It lacked per-instance economic capabilities,
   employment, schedule, payroll, and work tools.

## Domain distinction

`ProfessionDefinition` remains long-term character build/class identity.
`JobDefinition` is economic employment. They are never aliases and neither
resource contains mutable actor state.

## Shared actor capability model

```text
CharacterController (persistent identity)
├── WalletComponent          personal carried integer currency
├── InventoryComponent       owned item stacks
├── EquipmentComponent       16 canonical actor slots
├── SkillComponent           professional and combat proficiency
├── EnergyComponent          work/combat stamina
├── ActorAttributesComponent stable strength/vitality/dexterity/intelligence API
└── EmploymentComponent      contract, result summary, sequence, income
```

Player and NPC scenes use the same component scripts. NPC definitions contain
only authored initialization IDs/values. Every mutable component instance is a
scene child owned by one persistent actor.

## Wallet and Save v4 migration

`WalletComponent` is the sole owner of personal carried currency. It rejects
non-positive mutations, overdrafts, negative restore values, and integer
overflow. Its diagnostic history is bounded to 32 provenance records containing
actor, direction, reason, counterparty/worksite/shop, proposal, sequence, and
world time.

`PropertyBankService` now owns only bank deposits, home cash, investments,
property/deed state, and custodial inventories. For compatibility its
`wallet_balance` property delegates to the bound player wallet; it is not a
second stored balance. Combined player purchases still draw from bank first and
then carried currency.

Save major remains 4:

- property section v1/v2: read legacy `wallet_balance` once into player
  `WalletComponent` with migration provenance;
- property section v3: never writes `wallet_balance`;
- player section: writes the wallet component state;
- a second restart reads property v3 and player wallet state, so the migration
  cannot repeat.

## Commerce and equipment

`CommerceService` accepts an actor funds capability. Player calls pass the
bank-plus-wallet adapter; NPC calls pass their personal wallet. Buy/forge
transactions simulate the complete next inventory before funds are debited.
Sell transactions validate removal before credit. No actor-specific duplicate
commerce service exists.

`EquipmentEffectCalculator` aggregates shared authored bonuses and resolves the
best equipped work tool by generic `ItemDefinition.work_tags` and
`work_efficiency`. Both player bonus calculation and NPC effects consume the
shared calculator. Equip intents name an existing inventory slot/item and use
the existing atomic `equip_from_inventory` path; no intent can materialize an
item.

## Employment and work

Static resources:

- `JobDefinition`: skill, attributes, required/optional tool tags, supported
  worksite types, wage, cadence, energy cost, base output, action, shift hours;
- `WorkSiteDefinition`: type, region, allowed jobs, marker, capacity,
  efficiency, finite initial payroll.

Runtime data:

- `EmploymentContract`: persistent actor ID, job/worksite IDs, active status,
  start day, wage, shift;
- `EmploymentComponent`: current contract, last work day/result, completed
  actions, lifetime income, durable economic sequence;
- `WorkSiteRuntimeState`: current payroll, active persistent worker IDs,
  lifetime abstract units, last processed day;
- `WorkResult`: factual deterministic result and execution provenance.

The work formula is deterministic and contains no random or provider-controlled
input:

```text
work_units = base_output
           × skill_factor
           × attribute_factor
           × equipped_tool_factor
           × energy/fatigue_factor
           × workplace_factor
```

Factors are bounded. Work prevalidates actor state, identity, region, contract,
job/worksite compatibility, shift/schedule, proximity, required equipped tool,
energy, payroll, and next transaction sequence. A paid action commits finite
payroll debit, equal wallet credit, energy spend, proficiency practice, worksite
units, actor summary, sequence, and post-commit events. Insufficient payroll
causes no wallet, energy, skill, result, or event mutation.

## Intent and replay authority

`WorkIntent`, `PurchaseIntent`, and `EquipIntent` are `RefCounted` data classes
containing IDs, bounded quantities/slots, and a monotonic transaction sequence.
They have no node, callable, database, HTTP, `apply`, or `execute` capability.

```text
canonical NPC state + definitions + available offers
→ NPCEconomicPlanner
→ DETERMINISTIC_AI IntentProposal
→ WorldIntentValidator
→ WorldIntentExecutor
→ ActorEconomyService / WorkService / CommerceService / EquipmentComponent
→ canonical mutation
→ GameplayEvent
```

The next successful economic transaction must use
`EmploymentComponent.economic_sequence + 1`. The high-water mark is captured in
the actor snapshot. A replayed sequence is rejected after region reload and
after process restart without an unbounded UUID ledger. A failed commit does not
advance the sequence. `SourceKind.LLM`, player input, and system proposals do
not have NPC economic authority.

## Blacksmith vertical slice

Authored content provides:

- actor: `base:town/npc/blacksmith_0001` using `NPCDefinition.blacksmith`;
- job: `job:blacksmith`;
- worksite: `worksite:town_smithy`, payroll 500;
- skill: `smithing`;
- schedule: 08:00–19:00 at `TownSmithyWorkMarker`;
- starter tool: `starter_forge_hammer`, efficiency 1.0;
- upgrade offer: `improved_forge_hammer`, price 45, efficiency 1.35;
- starting wallet: 10; reserve: 10; wage: 25.

At work time the existing NPC controller moves to the marker, enters WORK, and
submits one bounded planner action per authored cadence. Two wages make the
upgrade affordable while retaining reserve. The planner buys it through
commerce, equips it through equipment, and later work produces a measurably
higher deterministic result.

## Events and debug inspection

Successful post-commit events are `NPC_WORKED`, `ACTOR_EARNED_WAGE`,
`ACTOR_PURCHASED`, and `ACTOR_EQUIPPED_ITEM`. Payloads include persistent actor,
job/worksite/item, quantity or money/work amount, world time, proposal, and
sequence as applicable. Cognition may observe these facts but owns none of the
underlying state.

The debug-build world panel initially selects the employed blacksmith and can
cycle loaded NPCs and interactables. It shows persistent ID and definition,
wallet transaction provenance, energy, job/worksite distance, payroll, state,
smithing, inventory, work tool, last work result, and economic sequence. Its
acceptance controls synthesize normal InputMap actions or use the canonical
region/session services; none can directly mutate actor economy. A debug-only
ActorFactory sibling action creates a second same-definition actor with a new
persistent ID so instance isolation can be observed and saved in a real build.

## Explicit 0.12+ boundary

0.11 work produces abstract units only. It does not implement business
inventory, merchant stock depletion, ore-to-item production, revenue, dynamic
pricing, supply/demand, needs economy, factions, territory, governance,
strategic simulation, or general off-screen employment.

## Automated proof

The 0.11 additions cover wallet mutation/provenance/serialization/isolation,
old property-wallet migration, actor snapshot isolation, inert intent data,
formula determinism and factor monotonicity, payroll conservation and failure
atomicity, purchase atomicity, worksite persistence, durable sequence restore,
reserve/tool planning, LLM rejection, blacksmith lifecycle, region reload,
Save/Continue, and post-restart replay rejection. The CI floor is 369 Godot
scripts, up from the accepted 355.
