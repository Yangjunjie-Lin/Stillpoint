# Stillpoint Living-World Roadmap

## Stage rule

Only one numbered phase is active at a time. A phase advances only after its
goal, automated tests, manual acceptance, compatibility, Save behavior, and
documentation are reviewed. Later phase descriptions are plans, not claims.

## Milestones

| Version | Goal | Entry dependency | Exit proof |
| --- | --- | --- | --- |
| 0.9.0 | World identity and simulation authority | Existing 0.8.0 playable slice | Shared product/domain language; authority/LLM boundary; typed-intent pilot; no regressions |
| 0.10.0 | Action camera and combat identity | Accepted 0.9.0 boundary | Switchable first/third person, lock-on/free aim, expanded coherent combat state, animation foundation |
| 0.11.0 | Embodied NPC economy, equipment, and work | Shared actor capability design stable | Isolated persistent NPC wallet/inventory/equipment/job; blacksmith work loop |
| 0.12.0 | Production economy and social survival | Per-actor economic agency | Conserved production/trade/stock/wages, food/rest/safety demand, scarcity pricing |
| 0.13.0 | Factions, territory, and governance | Economy can fund policy | Runtime factions/territories/offices/orders/succession; two-faction proof |
| 0.14.0 | Persistent world simulation | Work/economy/governance rules exist | Bounded physical/local/regional/strategic ticks and absence catch-up with provenance |
| 0.15.0 | Multi-origin world and content pipeline | Simulation supports multiple regions/factions | Data-driven cultures/origins/settlements/dungeons and distinct starts |
| 0.16.0 | Isekai life systems | Economy/social state can absorb them | Connected peaceful-life systems with world consequences |
| 0.17.0 | Dynamic history, rumors, and narrative | Durable canonical event history | Witness → memory → rumor → belief; quests arise from real needs |
| 0.18.0 | Visual fidelity and immersion | Core interactions and camera stable | Production character/world/combat presentation within budgets |
| 0.19.0 | Scale, performance, and integrity | All core world loops exist | Profiled long simulations, seeded reproduction, stable economy/politics |
| 1.0 | Living isekai vertical world | 0.19 integrity gates pass | End-to-end deep slice proves combat, life, society, politics, absence, and persistence |

## 0.9.0 scope and gate

This branch implements only 0.9.0:

- product identity and status labels;
- repository-wide system/authority inventory;
- formal domain, simulation, persistence, and LLM ownership;
- data-only `WorldIntent`, attributed `IntentProposal`, deterministic validator,
  simulation executor, and a single `TalkIntent` pilot;
- tests for inert proposals, rejected LLM/unsupported/out-of-range proposals,
  successful player-input execution, and event provenance;
- preservation checks for dialogue, pets, farming, commerce/property, dungeon,
  combat, region, and Save v4 paths.

0.10.0 must not start until 0.9.0 review accepts all of the following:

1. the full Godot and backend gates are green;
2. manual New Adventure, representative life/combat/dialogue/pet/dungeon play,
   Save, exit, and Continue succeed;
3. an LLM-attributed proposal demonstrably cannot mutate state;
4. README and architecture docs match the executable repository;
5. no new duplicate wallet, inventory, equipment, quest, dialogue, save, or
   player controller architecture has been introduced;
6. risks in [SYSTEM_INVENTORY.md](SYSTEM_INVENTORY.md) have owners or explicit
   deferral.

## 0.10.0 implementation notes

The feature branch starts from accepted `develop` and preserves one player
controller and one damage pipeline. The audit and runtime design are recorded
in [ACTION_CAMERA_COMBAT_0_10_0.md](design/ACTION_CAMERA_COMBAT_0_10_0.md).
Manual Debug Build acceptance remains a release gate; see
[ACTION_CAMERA_COMBAT_0_10_0_ACCEPTANCE.md](acceptance/ACTION_CAMERA_COMBAT_0_10_0_ACCEPTANCE.md).

## 0.11.0 implementation notes

The embodied NPC economy phase adds shared actor wallet/inventory/equipment and
attribute capabilities, one-time Save v4 property-wallet migration, jobs,
worksites, finite payroll, employment, deterministic work results, professional
skill progress, transactional economic intents, and durable replay protection.
The blacksmith vertical slice proves work → wage → tool purchase → equip →
improved output across region reload and Save/Continue. Design and scope are in
[NPC_ECONOMIC_AGENCY_0_11_0.md](design/NPC_ECONOMIC_AGENCY_0_11_0.md); manual
release evidence belongs in
[NPC_ECONOMIC_AGENCY_0_11_0_ACCEPTANCE.md](acceptance/NPC_ECONOMIC_AGENCY_0_11_0_ACCEPTANCE.md).

## 0.12.0 implementation notes

The production-economy phase adds immutable business/production definitions,
one persistent inventory and treasury per business, two-party staged commerce,
stock/revision quotes, deterministic scarcity and bounded demand memory, smithy
input/output production, retained forge revenue, and shared NPC food/rest/safety
needs. Save v4 section migration replaces 0.11 worksite payroll with the owning
business treasury once. Design and scope are in
[PRODUCTION_ECONOMY_0_12_0.md](design/PRODUCTION_ECONOMY_0_12_0.md); manual
release evidence belongs in
[PRODUCTION_ECONOMY_0_12_0_ACCEPTANCE.md](acceptance/PRODUCTION_ECONOMY_0_12_0_ACCEPTANCE.md).

0.13.0 remains responsible for faction treasuries, taxation, territory,
government, laws, offices, rulers, and diplomacy. 0.14.0 owns simulation LOD.
