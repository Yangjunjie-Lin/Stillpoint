# Stillpoint 0.11.0 NPC Economic Agency Acceptance

## Candidate

- Baseline develop: `1a91dda13ad9b4ff2eeeeff5c9d51c45bdce82d4`
- Feature branch: `feat/0.11.0-npc-economic-agency`
- Candidate Head: pending final commit
- Build: pending exact-head Windows Debug export
- Automated Godot result: pending final full gate (369-script floor)
- Manual result: not yet executed

Manual PASS must be recorded only from a real exact-head Debug Build. Automated
tests provide setup confidence but are not manual evidence.

## Blacksmith checklist

| # | Check | Result | Evidence / notes |
| --- | --- | --- | --- |
| 1 | Start New Adventure and locate Torren | PENDING | |
| 2 | Debug inspector shows unique persistent ID | PENDING | |
| 3 | Wallet, inventory, equipment, job, and worksite are visible | PENDING | |
| 4 | Job is Blacksmith; worksite is Town Smithy | PENDING | |
| 5 | Work schedule begins and NPC reaches the authored marker | PENDING | |
| 6 | NPC enters WORK and work presentation occurs | PENDING | |
| 7 | Exactly one bounded work result occurs per cadence | PENDING | |
| 8 | Energy decreases according to authored cost | PENDING | |
| 9 | Smithing proficiency increases | PENDING | |
| 10 | Payroll decreases and wallet increases by the same wage | PENDING | |
| 11 | No duplicate wage is observed | PENDING | |
| 12 | Repeated work makes the improved hammer affordable with reserve | PENDING | |
| 13 | Canonical purchase debits exact price and adds one owned tool | PENDING | |
| 14 | Canonical equip moves the improved hammer into equipment | PENDING | |
| 15 | Starter/new inventory and equipment state remains legal | PENDING | |
| 16 | Next work result improves with the better tool | PENDING | |

## Isolation and persistence checklist

| # | Check | Result | Evidence / notes |
| --- | --- | --- | --- |
| 17 | Two same-definition instances retain independent state | PENDING | Test/debug setup if practical |
| 18 | Leave town and return; all actor economic state remains | PENDING | |
| 19 | Worksite payroll remains exact after region reload | PENDING | |
| 20 | Save → Main Menu → Continue restores wallet/inventory/equipment | PENDING | |
| 21 | Continue restores employment/smithing/result/sequence/payroll | PENDING | |
| 22 | Previous wage/purchase/equip does not replay | PENDING | |

## Player and world regression checklist

| # | Check | Result | Evidence / notes |
| --- | --- | --- | --- |
| 23 | Player buy and sell | PENDING | |
| 24 | Forge transaction | PENDING | |
| 25 | Bank deposit/withdraw and home storage | PENDING | |
| 26 | NPC authored dialogue and free-form fallback | PENDING | |
| 27 | Third/first person, target lock, combat, dodge/parry | PENDING | |
| 28 | Farming, pets, dungeon smoke | PENDING | |

## Automated acceptance mapping

- Wallet/migration: `test_wallet_component_0_11`,
  `test_player_wallet_v4_migration_0_11`
- Isolation/snapshot: `test_npc_economic_snapshot_isolation_0_11`
- Work formula/payroll: `test_work_formula_determinism_0_11`,
  `test_payroll_conservation_0_11`, `test_insufficient_payroll_atomic_0_11`
- Commerce/planner: `test_npc_purchase_atomicity_0_11`,
  `test_npc_tool_upgrade_planner_0_11`
- Authority/replay: `test_economic_intent_data_contract_0_11`,
  `test_durable_economic_sequence_0_11`,
  `test_llm_economic_authority_blocked_0_11`
- End to end: `test_blacksmith_economic_vertical_0_11`,
  `test_blacksmith_economic_region_save_continue_0_11`

## Deferred scope verified

The candidate must contain no claim or implementation of business stock,
production chains, dynamic markets, food/rest/safety demand, faction treasury,
territory/governance, strategic simulation, or broad off-screen employment.
