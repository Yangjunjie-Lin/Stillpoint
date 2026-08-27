# Existing System Inventory (0.12.0 Audit)

Baseline audited after fetch: `develop` at
`aa37fee05456b6a2ba840d37be00dcc7be2567fe`.

The audit covered tracked scripts, scenes, resources, documentation, test
discovery, backend service/migrations, CI, launch tooling, and legacy paths.

## Subsystems

| Area | What exists | State owner | Status / boundary |
| --- | --- | --- | --- |
| Bootstrap/UI | Main menu, creation, settings/rebinding, HUD, dialogue, inventory/equipment, commerce, property, pet menus | Scene/UI controllers; no canonical ownership intended | Implemented; UI still calls several domain services directly |
| World session | Persistent root, one active region slot, world services, transitions, autosave, restore failure safety | `WorldSession` coordinates services | Implemented primary composition root |
| Regions | Town, farmland, wilderness, private home, dungeon; connected roads/doors and guarded dungeon travel | `RegionRuntimeService`, definitions, repository | Implemented streamed slice, not seamless world |
| Identity/entities | Definition ID, persistent ID, region ID, policy, snapshots, runtime spawn/destruction | `WorldEntityIdentity`, `WorldEntityRepository`, `ActorFactory` | Implemented and tested at 100/500 snapshot scale |
| Save | Save v4 manifest, critical/global sections, region chunks, backups, v3 migration, dirty tracking | `WorldSaveCoordinator`, `SaveSlotService`, providers | Implemented canonical local persistence |
| Events/quests | Typed `GameplayEvent`; Conditions; required/retryable Effects; objective/event routing | Coordinators plus `QuestManager` state | Implemented; Effects are trusted authored commands |
| Typed intents | Data-only talk/work/production/purchase/sale/consume/equip plus proposal/result | `WorldSession`-owned validator/executor | Player talk and deterministic NPC economics; no LLM execution |
| Combat | Animation-event hit windows, combo, skills, guard, energy, damage, hit stop, reaction, knockback, death/downed, Combat Lab | Components and actor controllers | Implemented prototype; camera/heavy/dodge/parry/poise planned |
| Character build | Origin, faction, profession, appearance, balanced stat allocation, starter kits | Definitions plus player Save state | Implemented for player; NPC career state absent |
| Inventory/equipment | Atomic inventory slots/transfers, 16 equipment slots, requirements, shared effects/work metadata | Per-actor components and snapshots | Shared player/NPC capability; containers also reuse inventory |
| Skills/progression | Active/passive/proficiency skills, cooldowns, practice context, daily caps/overtraining, XP/levels | Player/pet components | Implemented vertical slice |
| NPC behavior | Wander/schedule/navigation, bounded WORK cadence, aggression/combat, talk/downed/death | `NPCController`, shared components, relationship/economy services | Physical behavior plus blacksmith work/economic loop implemented |
| Dialogue/relationships | Authored deterministic dialogue/choices/effects, free-form dialogue, affinities and hostility | Dialogue/quest coordinators; `RelationshipService` | Implemented; deterministic and cognitive dialogue have distinct roles |
| Cognition backend | FastAPI, PostgreSQL/pgvector, Alembic, auth, profile catalog, memory, beliefs, graph visibility, provider abstraction, privacy, sync/outbox | Backend cognitive repository only | Experimental production-oriented service; not gameplay authority |
| Pets/mount | Three companion definitions, per-instance runtime, equipment, skills, routines, needs, combat support, off-screen updates; rideable mount | Pet runtime/controller, Save companions | Implemented pet vertical slice; provider movement output advisory only |
| Farming | Turnip definition, plots, till/seed/water/growth/harvest, rest/day advance, proficiency | `FarmPlot`, player inventory/energy, world time, region snapshots | Implemented coherent narrow loop |
| Commerce/forging | Static offers plus finite stock, quote revisions, player/NPC buy/sell, retained forge fees | `BusinessRuntimeState`, `CommerceService`, staged coordinator | Two-party conserved local commerce implemented |
| Housing/banking | House definitions, deed, storage, bank/home cash, investment, repossession/rebuild | `PropertyBankService`, Save global world | Player slice; pocket money delegated to player `WalletComponent` |
| Employment/production | Jobs/worksites/contracts, recipes, deterministic results and planner | Actor components, business/worksite runtime, `ActorEconomyService` | Smithy input/output/wage/revenue loop implemented |
| Social survival | Generic food metadata, deterministic world-time need cadence and priorities | NPC `NeedsComponent` | Food purchase/consume, rest, safety, stockout slice implemented |
| Dungeon/exploration | Level gate, authored dungeon, loot caches, boss tracking/respawn, hidden encounter slices | Dungeon/encounter services, repository, Save | Implemented vertical slice |
| Time/simulation | Authoritative clock, day/hour signals, physical/virtual mode query | `WorldTimeService`, placeholder `WorldSimulationService` | Time implemented; general abstract/regional/strategic simulation planned |
| Content/data | `.tres` catalogs for actors, minds, factions, origins, professions, skills, items, houses, shops, regions, dungeon, encounters, containers, loot, and spawns | `ResourceRegistry` treats definitions as authored data | Data-driven foundation; broader content pipeline planned |
| Tooling/tests | 380 Godot unit/integration scripts, backend unit/PostgreSQL tests, cross-process E2E, exporters, hygiene/secret scans, Windows launcher | CI/tool scripts | Strong automated foundation; manual acceptance remains required |
| Legacy survival | Separate 2D shooter scene/controller/hitbox/bullet/save path | Legacy mode only | Preserved compatibility; must not influence living-world domain design |

## Static definition versus runtime state

Static resources include items, attacks, characters/NPCs/minds, pets/species,
factions, origins, professions, skills, schedules, dialogues, quests, crops,
houses, shops/offers, recipes, regions, dungeons, encounters, containers, loot,
and spawns. They describe defaults and capabilities.

Runtime state includes transforms, health/energy/status, actor state, relationship
records, quest runtimes, inventory/equipment, skill progress, world flags, time,
discovery, region entity snapshots, pet state, dungeon state, property/banking,
and cognitive cache/outboxes. Persistent runtime data is in Save v4 or the
explicitly non-canonical cognition repository, never shared `.tres` fields.

## Current canonical mutation surface

- player and NPC controllers/components mutate movement, combat, stats, skills,
  inventory, equipment, and interaction state;
- `WorldEffect` subclasses mutate quest-relevant items, flags, relationships,
  spawns, destruction, travel, mounts/pets, and proficiency after coordinator
  conditions/ordering;
- farming interactables mutate plot/player state;
- commerce/property services mutate money, ownership, storage, trade, and forge
  results;
- region/dungeon/hidden-encounter services mutate world progression and entity
  snapshots;
- quest, relationship, flag, time, and pet state services own their domains;
- Save services serialize/restore state but are not decision makers.

0.9.0 does not mechanically route these mature trusted paths through intents.
It establishes the required boundary for future decision-layer requests.

## AI-controlled or AI-assisted paths

- NPC free-form dialogue: provider reply/memory/belief/intent candidates;
- NPC memory retrieval and graph traversal: scoped by player/save/NPC and
  visibility;
- pet dialogue: response only; gameplay intents stripped;
- pet movement assessment: bounded semantic weights cached at low frequency;
  Godot chooses anchors, coordinates, navigation, collision, and movement;
- deterministic fallbacks own correctness when AI is off or fails.

No current AI path owns inventory, equipment, money, health, quests, faction,
property, territory, spawn/destruction, teleport, or world flags.

## Duplicated or transitional responsibilities

| Duplication / seam | Finding | 0.9.0 decision |
| --- | --- | --- |
| `WorldManager` / `WorldSession` | Manager is a thin compatibility alias | Keep alias; new code targets `WorldSession` |
| `QuestManager` / `QuestCoordinator` | Manager stores runtime; coordinator owns transactional lifecycle | Keep both roles, forbid direct lifecycle calls in new integration code |
| `SaveService` / `WorldSaveService` / Save v4 services | Settings/legacy run, legacy world compatibility, and current Save v4 have different scopes | Document; do not merge during authority milestone |
| `PlayerController` / `PlayerController3D` | 2D legacy mode versus primary living-world player | Quarantine legacy; never fork a second 3D player for camera modes |
| 2D / 3D combat classes | Legacy shooter and current action-RPG pipeline coexist | Preserve legacy tests; 0.10 extends only 3D pipeline |
| Authored / cognitive dialogue | Deterministic quest effects versus optional expression/memory | Intentionally separate, coordinated by `DialogueCoordinator` |
| Player bank plus actor wallet | Bank service is a compatibility funds adapter over player wallet + bank | Resolved in 0.11; no second writable pocket-money store |
| Definition faction relations / relationship runtime | Faction defaults and actor affinities are separate concepts | Keep separate; add future faction runtime state rather than mutating definitions |

## Remaining architectural risks

1. Canonical mutators are distributed across components, interactables, Effects,
   and services; source policy is not yet uniformly expressed as intents.
2. The local economy simulates loaded actors/businesses on bounded cadence;
   regional/off-screen economic LOD remains 0.14.0 scope.
3. Factions have definitions but no runtime treasury, leader, offices, policy,
   territory, or diplomacy state. Owner: 0.13.0 faction runtime/governance.
5. General virtual simulation and bounded catch-up are placeholders. Owner:
   0.14.0 simulation LOD.
6. Several global autoload stores remain convenient singletons; future
   multi-world/test isolation may require session scoping.
7. Talk proposals retain session-local consumption; transactional economics use
   a persisted per-actor monotonic high-water sequence.
8. Property investment remains an authored player-finance subsystem outside the
   closed ordinary business-trade proof; taxation/public finance is 0.13+.
