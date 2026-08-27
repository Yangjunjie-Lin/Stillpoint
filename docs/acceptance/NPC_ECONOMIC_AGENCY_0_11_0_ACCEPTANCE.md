# Stillpoint 0.11.0 NPC Economic Agency Acceptance

## Candidate

- Baseline develop: `1a91dda13ad9b4ff2eeeeff5c9d51c45bdce82d4`
- Feature branch: `feat/0.11.0-npc-economic-agency`
- Candidate Head: pending final commit
- Build: real candidate-content Windows Debug export exercised; exact-final-head
  export and SHA-256 pending
- Automated Godot result: pending final full gate (369-script floor)
- Manual result: 28/28 PASS on the real candidate-content Windows Debug
  build; exact-final-head critical Continue smoke pending

Manual PASS must be recorded only from a real exact-head Debug Build. Automated
tests provide setup confidence but are not manual evidence.

## Blacksmith checklist

| # | Check | Result | Evidence / notes |
| --- | --- | --- | --- |
| 1 | Start New Adventure and locate Torren | PASS | Began the 0.11 open-world journey and located Torren in Town. |
| 2 | Debug inspector shows unique persistent ID | PASS | Inspector showed `base:town/npc/blacksmith_0001`. |
| 3 | Wallet, inventory, equipment, job, and worksite are visible | PASS | Inspector exposed wallet, inventory summary, equipped work tool, job, worksite, payroll, skill, work result, and sequence. |
| 4 | Job is Blacksmith; worksite is Town Smithy | PASS | `job:blacksmith` at `worksite:town_smithy`. |
| 5 | Work schedule begins and NPC reaches the authored marker | PASS | Torren followed the work schedule, navigated to the smithy, and reached the authored work marker. |
| 6 | NPC enters WORK and work presentation occurs | PASS | `WORK` state and the smithing presentation were observed at the smithy. |
| 7 | Exactly one bounded work result occurs per cadence | PASS | Sequence/work-action counts advanced once per cadence; final values were sequence 22 and 20 work actions, with no per-frame burst. |
| 8 | Energy decreases according to authored cost | PASS | Each successful work result spent the authored 8 energy; the inspector's final result recorded `energy 8.0`. |
| 9 | Smithing proficiency increases | PASS | Smithing advanced from 0.0 to 20.0 through work practice. |
| 10 | Payroll decreases and wallet increases by the same wage | PASS | Each paid result transferred 25 from smithy payroll to Torren; final payroll was 0 and lifetime income was 500. |
| 11 | No duplicate wage is observed | PASS | Wallet, payroll, and durable sequence changed once per accepted result and did not change again on region reload or Continue. |
| 12 | Repeated work makes the improved hammer affordable with reserve | PASS | Repeated wages funded the improved hammer while satisfying the authored wallet reserve policy. |
| 13 | Canonical purchase debits exact price and adds one owned tool | PASS | One 45-coin upgrade purchase changed Torren from 510 to 465 and produced exactly one improved forge hammer. |
| 14 | Canonical equip moves the improved hammer into equipment | PASS | The purchased item became `Work Tool: Improved Forge Hammer` through the equipment path. |
| 15 | Starter/new inventory and equipment state remains legal | PASS | After equip, the starter forge hammer remained in inventory x1 and the improved hammer occupied the work-tool equipment state; no impossible duplicate appeared. |
| 16 | Next work result improves with the better tool | PASS | The next improved-tool result exceeded the pre-upgrade sample; final result was units 17.76, quality 44.41, tool `improved_forge_hammer`. |

## Isolation and persistence checklist

| # | Check | Result | Evidence / notes |
| --- | --- | --- | --- |
| 17 | Two same-definition instances retain independent state | PASS | Primary `blacksmith_0001`: wallet 465, smithing 20, improved hammer, sequence 22/work 20/income 500. Sibling `blacksmith_debug_01`: wallet 10, smithing 0, starter hammer, sequence/work/income 0. |
| 18 | Leave town and return; all actor economic state remains | PASS | Travelled Town → Wilderness → Town; wallet, inventory, equipped tool, employment, skill, result, and sequence remained exact. |
| 19 | Worksite payroll remains exact after region reload | PASS | Town Smithy payroll remained 0 after region unload/reload. |
| 20 | Save → Main Menu → Continue restores wallet/inventory/equipment | PASS | Multiple Save & Main Menu → Continue cycles restored Torren wallet 465, starter hammer inventory x1, and improved hammer equipped. |
| 21 | Continue restores employment/smithing/result/sequence/payroll | PASS | Final Continue restored `job:blacksmith`, Town Smithy, smithing 20.0, units 17.76/quality 44.41/wage 25, sequence 22, 20 work actions, and payroll 0. |
| 22 | Previous wage/purchase/equip does not replay | PASS | Final Continue retained sequence 22 and wallet 465 without repeating the prior wage, 45-coin purchase, or equip mutation. |

## Player and world regression checklist

| # | Check | Result | Evidence / notes |
| --- | --- | --- | --- |
| 23 | Player buy and sell | PASS | Player purchase path succeeded; Edda bought one Padded Vest for 68, changing wallet 361 → 429 and removing the item with sale confirmation. |
| 24 | Forge transaction | PASS | Forged Greywake Iron Sword for 85: wallet 446 → 361; Iron Ore x3 and Training Sword were consumed, and the sword persisted through Continue. |
| 25 | Bank deposit/withdraw and home storage | PASS | Bank deposit/withdraw both succeeded. Home storage stored one Trail Snack (x3 → x2, store x1) and withdrew it (x2 → x3, store empty). |
| 26 | NPC authored dialogue and free-form fallback | PASS | Mira authored dialogue started `demo_errand`; Warden Aster showed authored choices plus free-form. Offline reply was `Hello. I'm here, but I need a moment before I can answer.` Debug panel hid during dialogue and returned on close. |
| 27 | Third/first person, target lock, combat, dodge/parry | PASS | Third → first → third camera, target lock, normal combat, dodge, and guard/parry input were exercised; Veyra was defeated normally and the player reached level 3. |
| 28 | Farming, pets, dungeon smoke | PASS | Farming and pet menus/actions worked; dungeon traversal, combat, Veyra kill, and loot pickup completed. |

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
