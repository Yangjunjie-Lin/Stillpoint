# Production Economy 0.12.0 Manual Acceptance

Status: PARTIAL, 38/63 PASS. The release manual gate is not yet satisfied.
Automated tests are recorded separately and do not substitute for unchecked
physical observations.

Build requirement: real Windows Debug export from the exact feature head. Mark
an item PASS only after physically observing it in that build.

## Evidence

- Candidate branch: `feat/0.12.0-production-economy-survival`
- Windows Debug build:
  `builds/stillpoint_windows_0.12.0_debug.exe`
- Build type: Godot 4.7.1 Windows Debug export
- Tester: Codex, through the Windows Computer Use observation/action loop
- Date: 2026-08-27 (Europe/London)
- Evidence medium: in-thread Windows captures plus the observations below
- Exact-head caveat: the full run preceded the final documentation commit; a
  post-fix export physically confirmed the main-menu label
  `0.12.0 · SAVE v4`. A complete exact-head rerun is still required.

Observed run summary:

- Fresh town load exposed both business treasuries, canonical inventories,
  demand scores, price revisions, quotes, and actor/business sequences.
- Six smithy batches consumed finite ore from 12 to 0 and produced six iron
  bracers. Smithing advanced to 6.0 and six exact 25-coin wages moved from the
  smithy to Torren. A further acceptance step at zero ore did not advance
  output, wage, skill, energy, or either sequence.
- Torren bought the improved hammer for 45 coin; smithy revenue then funded
  later wages. The player bought a produced bracer for 198 coin: wallet
  493 -> 295, treasury 395 -> 593, stock 6 -> 5, quote 198 -> 237.
- The player bought a trail snack for 12 coin: wallet 500 -> 488, provisions
  treasury 250 -> 262, stock 8 -> 7, price 12 -> 13. Selling one snack back
  moved wallet 488 -> 493, treasury 262 -> 257, stock 7 -> 8, price 13 -> 12.
- Torren's food/rest needs rose on hourly cadence. At food 0.61 he bought a
  7-coin turnip: wallet 115 -> 108, provisions treasury 257 -> 264, turnips
  12 -> 11. The next deterministic action consumed it and food need fell to
  0.42; the actor sequence advanced from 8 to 10.
- A real targeted attack raised safety from 0.00 to 0.35 and then 0.67. Torren
  entered `ATTACK`, counterattacked, and dealt 10 player HP damage.
- Town -> farm -> town preserved the recorded smithy/provisions state. Save ->
  Main Menu -> Continue restored smithy 593/sequence 8/revision 8/ore 0/bracers
  5; provisions 264/sequence 3/revision 3/turnips 11; and Torren wallet 108,
  sequence 10, food 0.48, rest 0.65, safety 0.67.
- A separate non-combat nighttime rest observation was not completed; the
  prior 22:00 observation still had the deliberately triggered attack active
  and therefore is not counted as authored rest evidence.

## Business and quotes (8/8)

- [x] New Adventure starts and the debug acceptance inspector opens.
- [x] Smithy shows finite treasury and one finite canonical inventory.
- [x] Provisions shows finite treasury and one finite canonical inventory.
- [x] Static offer rows show runtime stock and quote prices.
- [x] Displayed stock matches the debug business inventory.
- [x] Quote revision is visible and changes with canonical stock change.
- [x] Low stock price is higher than healthy-stock price for the same item.
- [x] Replenishment moves price downward; zero stock disables purchase.

## Production and feedback (12/13)

- [x] Torren reaches the authored smithy marker and starts production.
- [x] Two iron ore are removed for each one authored output created.
- [x] Output enters smithy business inventory.
- [x] Worker energy falls and smithing proficiency rises.
- [x] Smithy treasury pays the exact wage; worker wallet receives it.
- [x] Actor and business sequences advance once; no duplicate wage occurs.
- [x] Repeated production eventually reaches finite-input stockout.
- [x] Missing input creates no output/wage/skill/energy/sequence change.
- [x] Player purchases produced stock; item moves business -> player.
- [x] Player payment moves wallet/bank -> smithy treasury exactly.
- [x] Smithy revenue raises retained treasury.
- [x] A later wage is funded by retained treasury with no hidden top-up.
- [ ] Insolvent business fails cleanly and never becomes negative.

## Actor sale and forge (3/8)

- [x] A supported actor item can be sold to a buying business.
- [x] Item moves actor -> business exactly once.
- [x] Money moves business -> actor exactly once.
- [ ] Full business inventory rejects buyback without mutation.
- [ ] Insufficient treasury rejects buyback without mutation.
- [ ] Player forge consumes player-owned ingredients only.
- [ ] Forged output enters player inventory.
- [ ] Exact forge service fee enters smithy treasury.

## Food, rest, and safety (7/12)

- [x] Loaded NPC food need rises on world-time cadence.
- [x] Hungry NPC without food chooses a real in-stock provisions quote.
- [x] NPC wallet falls and provisions treasury rises exactly.
- [ ] Provisions stock falls and NPC inventory gains food exactly before the
  next action consumes it; the intermediate inventory state was not captured.
- [x] Next deterministic decision consumes the owned food.
- [x] Food leaves inventory and food need improves.
- [ ] Empty provisions stock yields wait fallback, no item, and no money loss.
- [x] Rest need rises while awake/working.
- [ ] Authored non-work rest lowers rest need and restores coherent energy.
- [x] A real aggression event raises safety need.
- [ ] Critical safety suppresses non-essential commerce/work; observed safety
  reached 0.67, below the authored 0.75 critical threshold.
- [ ] No LLM/provider output directly mutates needs, stock, price, or
  production; automated authority tests pass, but that is not manual evidence.

## Persistence and replay (5/12)

- [x] Record non-default business inventory/treasury/revision/demand/sequences.
- [x] Leave town and return; all business values remain exact.
- [x] Record non-default NPC needs/wallet/inventory/employment/sequence.
- [x] Save, Main Menu, Continue; business values remain exact.
- [x] Save, Main Menu, Continue; NPC values remain exact.
- [ ] Replaying the last actor sequence is rejected with no mutation/event.
- [ ] Replaying the last business sequence is rejected with no mutation/event.
- [ ] Production, purchase, sale, forge, and wage cannot duplicate after
  restart.
- [ ] Accepted 0.11 Save v4 loads with player/NPC state preserved.
- [ ] Legacy smithy payroll becomes the smithy treasury once.
- [ ] Save/reload after migration does not add payroll again.
- [ ] No business stock or treasury resets on UI open/day change/NPC spawn;
  UI-open and region-reload retention were observed, but not all three cases.

## Regression smoke (3/10)

- [ ] First-/third-person camera, free aim, target lock, combat, dodge/parry;
  camera, target lock, and combat were observed, but dodge/parry were not.
- [ ] Authored dialogue and free-form offline/provider fallback.
- [ ] Pets and mount.
- [ ] Farming and explicit crop harvest source.
- [ ] Dungeon travel/progression/loot.
- [ ] Property, bank, home cash, investment, storage.
- [ ] Player backpack/equipment/skills.
- [x] 0.11 tool-upgrade blacksmith loop.
- [x] Save/Continue and region travel.
- [x] No unexpected debug errors or visible state corruption.

## Result

Production Economy acceptance: 38/63 PASS - PARTIAL, RELEASE BLOCKED.

Do not mark the release manual gate PASS, mark the PR ready, or merge until all
63 checks have direct evidence from one exact-head Windows Debug export.
