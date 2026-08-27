# Domain Model

## Modeling rules

- Definitions are immutable authored resources and reusable kinds.
- Runtime state belongs to a persistent instance ID and is saved independently.
- Components express reusable actor capabilities; input control does not define
  different economic or physical laws.
- References use stable IDs. Node names, scene paths, and instance IDs are not
  durable identity.
- Cognitive memories/beliefs are scoped by player profile, world save, and actor
  persistent ID; they are not canonical state.

## Core domains

| Domain | Definition / identity | Runtime owner | 0.12.0 status |
| --- | --- | --- | --- |
| Actor | Persistent entity with character/pet definition | Controller, components, `WorldEntityIdentity`, `EntitySnapshot` | Implemented foundation |
| Player | `CharacterDefinition` plus origin/faction/profession choices | `PlayerController3D`, shared components, Save v4 player section | Implemented |
| NPC | `NPCDefinition` and optional `NPCMindDefinition` | `NPCController`, shared components, relationship service, cognition scope | Persistent embodied actor; blacksmith economic vertical implemented |
| Pet | `PetCompanionDefinition`, species/personality/lifestyle/skills | `PetRuntimeState`, `PetController`, Save companions | Implemented vertical slice |
| Faction | `FactionDefinition` | Player/NPC faction component only | Static relations/reputation implemented; runtime polity planned |
| Territory | Future definition and runtime state | Future strategic simulation | Planned 0.13.0 |
| Settlement | Region/building content is present; formal definition absent | Future regional state | Planned 0.13.0 |
| Profession | `ProfessionDefinition` | Player `profession_id` | Long-term build/class identity; distinct from employment |
| Skill | `SkillDefinition`; cognitive skills are deliberately separate | `SkillComponent` / pet skill state | Implemented proficiency and combat skills |
| Job | `JobDefinition` | Per-actor `EmploymentContract` / `EmploymentComponent` | Implemented economic employment role |
| WorkSite | `WorkSiteDefinition` with owning business ID | `WorkSiteRuntimeState` in `ActorEconomyService` | Operational workers/work units; no money ownership |
| Business | `BusinessDefinition`, shop/offers, production/forge recipes | One `BusinessRuntimeState` inventory/treasury/sequence/price ledger | Persistent finite local economy implemented |
| Needs | Generic actor satiation plus authored behavior thresholds | NPC `NeedsComponent` | Food/rest/safety world-time slice implemented |
| Wallet | Personal carried integer currency | Per-actor `WalletComponent`; bank/property accounts remain separate | Shared player/NPC capability implemented |
| Inventory | `ItemDefinition` describes items | Per-actor/container `InventoryComponent` | Shared actor capability with entity snapshot persistence |
| Equipment | Item equip/work metadata | Per-actor `EquipmentComponent`; pet runtime equipment | Shared player/NPC rules and effects implemented |
| Property | `HouseDefinition` | `PropertyBankService` deed/cash/storage state | Implemented player slice |
| Dungeon | `DungeonDefinition`, NPC/loot definitions | `DungeonProgressionService`, repository snapshots, Save v4 | Implemented vertical slice |
| WorldEvent | `WorldEventDefinition` for authored events | `GameplayEvent` is the completed canonical fact | Implemented event foundation |
| WorldIntent | Typed data class such as `TalkIntent` | Validator/executor owned by `WorldSession` | Implemented 0.9.0 pilot |

## Actor composition target

```text
Actor (persistent_id, definition_id, region_id)
├── identity and appearance
├── attributes / health / energy / status
├── inventory / equipment / wallet
├── skills / profession / job
├── faction / social and political roles
├── property / home / workplace
├── relationships
├── schedule / goals / needs
└── cognition scope (knowledge, beliefs, memories; non-canonical)
```

The player, NPCs, and pets may support different subsets, but shared
capabilities use shared rules. A player is primarily distinguished by an input
source, not by a separate economy.

## Definition versus runtime examples

| Static definition | Per-instance runtime state |
| --- | --- |
| `NPCDefinition.display_name`, role, home, economic initialization IDs | Health, region, wallet, inventory, equipment, employment, skill, sequence |
| `JobDefinition` skill/tags/wage/output policy | Actor contract, last result, sequence, income |
| `WorkSiteDefinition` type/marker/efficiency/business ID | Active workers, lifetime work units |
| `BusinessDefinition` identity/links/initial stock/cash/targets/recipes | Treasury, inventory, demand, prices, sales, actor-independent sequence |
| `ItemDefinition` stats, equip slots, work tags/efficiency | Owning inventory, quantity, equipped slot, future durability |
| `FactionDefinition` name, colors, authored relations | Future treasury, leader actor ID, territory, diplomacy, policies |
| `HouseDefinition` plan, value, capacity | Owner principal, deed status, cash, stored items |
| `PetCompanionDefinition` species/personality defaults | Nickname, needs, bond, equipment, skills, routine, region |

Runtime data must never be written back into a `.tres` definition or shared by
two instances created from the same definition.

## Profession versus job

A profession is long-term character specialization/build identity (for
example Guardian or Pathfinder). A job is an economic employment role (for
example Blacksmith or Courier). One actor may therefore have
`profession_id = guardian` and `job_id = job:blacksmith`; the concepts and
resources are deliberately separate.

## Event and intent semantics

- `WorldIntent`: "an actor wants to do X."
- `IntentProposal`: "source S proposes that actor A do X."
- `IntentValidationResult`: "current rules permit/reject X for reason R."
- executor/domain service: commits the valid change atomically.
- `GameplayEvent`: "X happened," with source, target, definition, region, time,
  amount, and bounded payload.

Only the final event may feed quests, witnesses, memories, rumors, and history
as a completed fact.
