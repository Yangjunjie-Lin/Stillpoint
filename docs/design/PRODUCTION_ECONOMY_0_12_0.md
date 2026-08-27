# Production Economy and Social Survival 0.12.0

Status: implementation audit, based on `origin/develop` at
`aa37fee05456b6a2ba840d37be00dcc7be2567fe`.

## Scope and invariants

0.12 owns the loaded-region, persistent local business economy: finite business
cash and inventory, authored production transformations, two-party trade,
bounded scarcity prices, actor needs, deterministic need-driven decisions, and
durable actor/business replay protection. Money and items are conserved across
ordinary transfers. Only explicitly authored production recipes may transform
items, and sources/sinks (for example crop harvest and food consumption) are
identified in canonical event payloads.

Faction treasuries, taxation, law, territory, government, strategic regional
simulation, general simulation LOD, and emergent history remain 0.13+ work.

## Baseline audit

| Area | Existing static definition | Existing runtime owner | 0.12 runtime owner / migration | Deferred responsibility |
| --- | --- | --- | --- | --- |
| Shop catalogue | `ShopDefinition` and `ShopOfferDefinition` | None; `CommerceService` treats every authored offer as unlimited | Offers remain immutable authorization/base-price facts; `BusinessRuntimeState.inventory` owns quantity | Remote-market and regional LOD stock |
| Worksite | `WorkSiteDefinition` | `WorkSiteRuntimeState` owns work totals and 0.11 payroll | Worksite keeps operational fields and references `business_id`; section v1 payroll migrates once into the matching business treasury | Faction or government employment |
| Business | None | None | `BusinessDefinition` plus one `BusinessRuntimeState` per definition | Ownership shares, tax, faction treasury |
| Actor cash | `NPCDefinition.starting_wallet_balance`; player property policy | `WalletComponent`; player bank adapter in `PropertyBankService` | Unchanged; transactions stage both payer and business receiver | Credit, lending, tax |
| Business cash | `WorkSiteDefinition.initial_payroll_funds` | `WorkSiteRuntimeState.payroll_balance` | `BusinessRuntimeState` is the only mutable owner; authored initial treasury is setup-only | Faction treasury and public budgets |
| Actor inventory | `ItemDefinition` | `InventoryComponent` | Unchanged participant in staged trade/consume transactions | Provenance per stack |
| Business inventory | Shop offers imply items | None | One `InventoryComponent` owned by `BusinessRuntimeState`; shop, production and buyback share it | Physical multi-warehouse custody |
| Forge | `ForgeRecipeDefinition` | Player inventory plus disappearing fee | Player materials remain actor-owned; service fee is transferred to the matching business treasury | Contract crafting queues |
| Production | Abstract job output only | `WorkService` mutates energy/skill/payroll | `ProductionRecipeDefinition`, `ProductionIntent`, staged input/output/wage commit | Industrial chains and off-screen LOD |
| Replay | Intent sequence in `EmploymentComponent` | Actor high-water mark | Actor mark remains; business gains a persistent high-water mark and price revision; plans verify both before commit | Distributed/database transactions |
| Needs | Pet-specific nutrition only | Pet domain | Shared NPC `NeedsComponent` owns bounded food/rest/safety; `pet_nutrition` is not reused as human satiation | Punitive player survival |
| Time cadence | `WorldTimeService` | Schedule/day/hour signals | Needs and demand decay advance on deterministic world-time intervals, never render frames | General simulation LOD |
| Persistence | Save v4 global-world and entity component snapshots | `actor_economy` v1 stores worksites; actor components store actor state | `actor_economy` section v2 stores businesses/worksites; entity snapshot key `needs`; v1 payroll migration is idempotent after re-save | Save major v5 |

## Content audit

The baseline has two shops: the bank equipment counter (player buyback enabled)
and the smithy counter. Neither has runtime stock or a receiving treasury. The
town smithy is the only worksite and starts with 500 units of mutable payroll.
The blacksmith job consumes energy and pays 25 per successful abstract work
action. `iron_ore` and forged equipment already exist, as does the accepted
blacksmith NPC/work/equipment loop.

Food items are `trail_snack` and `turnip`. Both are actor-consumable, but their
existing `pet_nutrition` metadata is pet-specific and neither has useful 0.11
commerce prices. Turnip harvest is already an explicit farming source: a
watered mature crop consumes its planted state and adds the authored harvest
quantity to player inventory. 0.12 will add generic actor satiation metadata and
an authored finite provisions business without changing that source boundary.

## Transaction model

The bounded coordinator follows:

1. validate identities, definitions, location/policy, quantities, balances,
   stock/capacity, quote revision, and actor/business sequences;
2. capture each mutable participant's pre-state;
3. prepare a data-only `EconomicTransactionPlan` with complete next-state
   deltas and event provenance;
4. perform final sequence/revision authorization;
5. apply the staged states and high-water marks;
6. restore captured state if any commit step reports failure;
7. emit canonical events only after a successful commit.

This is a single-process staged transaction with rollback. It does not claim
database ACID or distributed isolation. NPC and player commerce both carry a
persistent actor high-water mark alongside the business high-water mark; the
player mark is stored in the Save v4 player section.

## Pricing policy

For base price `B`, current stock `S`, target `T >= 1`, and bounded demand score
`D` in `[-1, 1]`:

```text
stock_ratio = S / T
scarcity = clamp(1.5 - 0.5 * stock_ratio, 0.5, 3.0)
demand = clamp(1.0 + 0.15 * D, 0.85, 1.15)
unit_price = clamp(round(B * scarcity * demand), 1, 1_000_000)
```

Stock at target yields the base price; lower stock raises price; excess stock
lowers it. A daily deterministic EWMA decay bounds demand memory. A stock or
demand change increments `price_revision`; quotes carry that revision and the
quoted world day/hour. Transactions never silently substitute a new price.

## Needs policy

Needs use `0.0 = satisfied` and `1.0 = critical`. Loaded NPCs advance them from
world-time intervals. Work raises food/rest pressure faster, non-work hours
provide the authored rest path, and canonical aggression raises safety. Food is
removed before satiation is applied. Critical food may spend below the normal
tool-upgrade reserve only down to a small authored emergency reserve; ordinary
upgrades retain the existing reserve. Critical safety suppresses optional
commerce/work. The LLM can observe these facts but cannot mutate them.

## Persistence and migration

The Save v4 container remains unchanged. `actor_economy.section_version` moves
from 1 to 2. When a v1 section is restored, each legacy worksite payroll balance
is assigned to its authored business treasury, replacing (not adding to) the
business default. The restored worksite drops payroll. A subsequent v2 save has
no payroll field, so reloading cannot repeat the migration. Missing economy data
creates authored defaults. Actor `needs` state is restored through the existing
entity component snapshot mechanism. The player economic sequence is restored
from the player section so buy, sale, and forge replay checks survive Continue.

## Authored boundaries

- Crop harvest: authored resource source (`crop_harvest`) with crop/item,
  quantity, actor, region, and world time.
- Production: recipe-authorized transformation with consumed and produced item
  maps, worker, business, worksite, and world time.
- Trade: exact item and money transfer with buyer/seller/business and quote
  provenance.
- Consumption: authored resource sink (`actor_consumption`) with item, quantity,
  actor, need delta, and world time.
- No shop-open, daily reset, or NPC-spawn path replenishes business state.
