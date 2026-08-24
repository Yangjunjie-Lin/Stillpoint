# Stillpoint 0.10.0 Action Camera and Combat Acceptance

Debug-build manual acceptance is separate from the automated suite. A row may
change from `NOT RUN` only after it is observed in a Windows Debug export built
from the candidate code. Automated coverage is supporting evidence, not a
substitute for this walkthrough.

## Execution record

- Status: **COMPLETE**
- Candidate Head: `a13eb3556ce21b47c61ee892c4b48f5acf51e6b1`
- Test date/time: physical walkthrough completed by the repository owner before
  and confirmed at 2026-08-24T16:54:42+01:00 (2026-08-24T15:54:42Z)
- Godot: 4.7.1.stable.official.a13da4feb
- Windows Debug Build:
  `artifacts/manual-acceptance/candidate-a13eb355-exact-20260823-205326/Stillpoint-0.10.0-a13eb355-exact-windows-debug.exe`,
  Windows x86_64, exported 2026-08-23T20:53:57.928+01:00
- SHA-256: `176BBD560938A40493E193F21B732CDBED6F2AD41693C3EABB382CB6B1134695`
- Local build provenance:
  `artifacts/manual-acceptance/candidate-a13eb355-exact-20260823-205326/BUILD_MANIFEST.md`
- Automated supporting gate: exact-Head GitHub Actions run `32454595513`,
  11/11 PASS; Godot `355 passed, 0 failed`; unexpected script/runtime errors 0;
  ObjectDB/resource leaks 0
- Manual Debug Build: **93/93 PASS**
- Physical evidence: repository-owner confirmation of the completed physical
  Windows keyboard/mouse walkthrough in the Codex release-closure task
  transcript at 2026-08-24T16:54:42+01:00. Table evidence below records that
  attestation; automated or synthetic input was not substituted for any row.

### Physical result summary

- Camera: 16/16 PASS
- Targeting: 10/10 PASS
- Third-person combat: 17/17 PASS
- First-person combat: 8/8 PASS
- Living world: 13/13 PASS
- Save/Continue: 14/14 PASS
- Combat Lab: 15/15 PASS
- Target cycling (row 19): physical `R` lock, `]` forward three-target cycle
  `A -> B -> C -> A`, stable forward repetition, `[` reverse cycle
  `A -> C -> B -> A`, both wraparounds, `R` unlock, and normal re-lock PASS.

### Previous interrupted attempt — not acceptance evidence

The attempt verified the 0.10.0 menu, camera settings layout, settings save,
New Adventure character creation, and entry into the third-person town scene.
It exposed and led to a fix for retained non-modal HUD focus suppressing camera
input. The fixed code passed the full automated gate and was re-exported. The
required rerun could not continue because the Windows computer-use controller
stopped delivering keyboard input and then failed recovery with
`failed to activate captured window`. No row below is claimed from that partial
attempt. The user's pre-existing save and settings were backed up and restored.

## Manual walkthrough

Evidence labels below refer to the repository owner's physical Windows
keyboard/mouse walkthrough confirmed at 2026-08-24T16:54:42+01:00.

| # | Area | Check | Status | Evidence |
| ---: | --- | --- | --- | --- |
| 1 | Camera | Start New Adventure | PASS | PHY-CAM-20260824 |
| 2 | Camera | Third-person movement | PASS | PHY-CAM-20260824 |
| 3 | Camera | Rotate camera 360 degrees | PASS | PHY-CAM-20260824 |
| 4 | Camera | Walk/run in multiple camera orientations | PASS | PHY-CAM-20260824 |
| 5 | Camera | Camera collision against a wall | PASS | PHY-CAM-20260824 |
| 6 | Camera | Camera collision in a narrow interior | PASS | PHY-CAM-20260824 |
| 7 | Camera | Switch to first person | PASS | PHY-CAM-20260824 |
| 8 | Camera | First-person horizontal look | PASS | PHY-CAM-20260824 |
| 9 | Camera | First-person vertical look | PASS | PHY-CAM-20260824 |
| 10 | Camera | First-person walk/run/jump/crouch | PASS | PHY-CAM-20260824 |
| 11 | Camera | Repeated FP/TP switching | PASS | PHY-CAM-20260824 |
| 12 | Camera | Shoulder swap | PASS | PHY-CAM-20260824 |
| 13 | Camera | FOV and sensitivity settings | PASS | PHY-CAM-20260824 |
| 14 | Camera | Open and close pause | PASS | PHY-CAM-20260824 |
| 15 | Camera | Open and close inventory | PASS | PHY-CAM-20260824 |
| 16 | Camera | Mouse capture restores after modal UI | PASS | PHY-CAM-20260824 |
| 17 | Targeting | Lock a valid enemy | PASS | PHY-TGT-20260824 |
| 18 | Targeting | Strafe around the locked enemy | PASS | PHY-TGT-20260824 |
| 19 | Targeting | Cycle targets deterministically | PASS | PHY-TGT19-20260824: R lock/unlock/re-lock; three-target forward/reverse cycles and wraparounds |
| 20 | Targeting | Briefly obscure target | PASS | PHY-TGT-20260824 |
| 21 | Targeting | LOS grace retains then expires lock | PASS | PHY-TGT-20260824 |
| 22 | Targeting | Target outside range clears lock | PASS | PHY-TGT-20260824 |
| 23 | Targeting | Kill locked target | PASS | PHY-TGT-20260824 |
| 24 | Targeting | Dead target lock clears | PASS | PHY-TGT-20260824 |
| 25 | Targeting | Enter first person while targeting | PASS | PHY-TGT-20260824 |
| 26 | Targeting | First-person targeting/free aim remains coherent | PASS | PHY-TGT-20260824 |
| 27 | Combat | Third-person light combo | PASS | PHY-CMB-20260824 |
| 28 | Combat | Third-person heavy attack | PASS | PHY-CMB-20260824 |
| 29 | Combat | Normal guard | PASS | PHY-CMB-20260824 |
| 30 | Combat | Successful parry | PASS | PHY-CMB-20260824: parryable/correct-timing case |
| 31 | Combat | Failed parry timing becomes normal guard/damage | PASS | PHY-CMB-20260824: parryable/incorrect-timing case |
| 32 | Combat | Non-parryable attack cannot be parried | PASS | PHY-CMB-20260824: non-parryable/correct-apparent-timing case |
| 33 | Combat | Dodge forward | PASS | PHY-CMB-20260824 |
| 34 | Combat | Dodge backward | PASS | PHY-CMB-20260824 |
| 35 | Combat | Dodge sideways | PASS | PHY-CMB-20260824 |
| 36 | Combat | Damage rejected inside dodge iframe | PASS | PHY-CMB-20260824: inside-iframe controlled case |
| 37 | Combat | Damage applies outside dodge iframe | PASS | PHY-CMB-20260824: outside-iframe controlled case |
| 38 | Combat | Trigger poise break | PASS | PHY-CMB-20260824 |
| 39 | Combat | Observe stagger and recovery | PASS | PHY-CMB-20260824 |
| 40 | Combat | Observe hitstun and recovery | PASS | PHY-CMB-20260824 |
| 41 | Combat | Observe blockstun and recovery | PASS | PHY-CMB-20260824 |
| 42 | Combat | Verify knockback | PASS | PHY-CMB-20260824 |
| 43 | Combat | Use active skill | PASS | PHY-CMB-20260824 |
| 44 | First-person combat | Light attack | PASS | PHY-FPC-20260824 |
| 45 | First-person combat | Heavy attack | PASS | PHY-FPC-20260824 |
| 46 | First-person combat | Guard | PASS | PHY-FPC-20260824 |
| 47 | First-person combat | Parry | PASS | PHY-FPC-20260824 |
| 48 | First-person combat | Dodge | PASS | PHY-FPC-20260824 |
| 49 | First-person combat | Active skill | PASS | PHY-FPC-20260824 |
| 50 | First-person combat | Switch to third person in a safe combat state | PASS | PHY-FPC-20260824 |
| 51 | First-person combat | No duplicate damage or event after switch | PASS | PHY-FPC-20260824 |
| 52 | Living world | Authored NPC dialogue | PASS | PHY-WLD-20260824 |
| 53 | Living world | Free-form dialogue with Backend available | PASS | PHY-WLD-20260824 |
| 54 | Living world | Backend-offline dialogue fallback | PASS | PHY-WLD-20260824 |
| 55 | Living world | Pet follow/stay/explore | PASS | PHY-WLD-20260824 |
| 56 | Living world | Pet UI and equipment | PASS | PHY-WLD-20260824 |
| 57 | Living world | Farming | PASS | PHY-WLD-20260824 |
| 58 | Living world | Buy and sell | PASS | PHY-WLD-20260824 |
| 59 | Living world | Forge | PASS | PHY-WLD-20260824 |
| 60 | Living world | Bank and property | PASS | PHY-WLD-20260824 |
| 61 | Living world | Dungeon entry | PASS | PHY-WLD-20260824 |
| 62 | Living world | Dungeon combat | PASS | PHY-WLD-20260824 |
| 63 | Living world | Loot and progression | PASS | PHY-WLD-20260824 |
| 64 | Living world | Return from dungeon | PASS | PHY-WLD-20260824 |
| 65 | Save/Continue | Save during safe runtime state | PASS | PHY-SAV-20260824 |
| 66 | Save/Continue | Exit to menu | PASS | PHY-SAV-20260824 |
| 67 | Save/Continue | Continue | PASS | PHY-SAV-20260824 |
| 68 | Save/Continue | Character build preserved | PASS | PHY-SAV-20260824 |
| 69 | Save/Continue | Inventory preserved | PASS | PHY-SAV-20260824 |
| 70 | Save/Continue | Equipment preserved | PASS | PHY-SAV-20260824 |
| 71 | Save/Continue | Finances/property preserved | PASS | PHY-SAV-20260824 |
| 72 | Save/Continue | Farm and region state preserved | PASS | PHY-SAV-20260824 |
| 73 | Save/Continue | Quests and relationships preserved | PASS | PHY-SAV-20260824 |
| 74 | Save/Continue | Pet state preserved | PASS | PHY-SAV-20260824 |
| 75 | Save/Continue | Cognition state/cache policy preserved | PASS | PHY-SAV-20260824 |
| 76 | Save/Continue | Dungeon state preserved | PASS | PHY-SAV-20260824 |
| 77 | Save/Continue | Camera preference follows settings policy | PASS | PHY-SAV-20260824 |
| 78 | Save/Continue | No transient combat state restored | PASS | PHY-SAV-20260824 |
| 79 | Combat Lab | Open Combat Lab | PASS | PHY-LAB-20260824 |
| 80 | Combat Lab | Third-person camera | PASS | PHY-LAB-20260824 |
| 81 | Combat Lab | First-person camera | PASS | PHY-LAB-20260824 |
| 82 | Combat Lab | Camera collision | PASS | PHY-LAB-20260824 |
| 83 | Combat Lab | Target lock and cycling | PASS | PHY-LAB-20260824 |
| 84 | Combat Lab | Heavy attack | PASS | PHY-LAB-20260824 |
| 85 | Combat Lab | Guard | PASS | PHY-LAB-20260824 |
| 86 | Combat Lab | Successful parry | PASS | PHY-LAB-20260824 |
| 87 | Combat Lab | Failed/non-parryable parry cases | PASS | PHY-LAB-20260824 |
| 88 | Combat Lab | Dodge iframe | PASS | PHY-LAB-20260824 |
| 89 | Combat Lab | Poise and stagger | PASS | PHY-LAB-20260824 |
| 90 | Combat Lab | Hitstun and blockstun | PASS | PHY-LAB-20260824 |
| 91 | Combat Lab | Knockback | PASS | PHY-LAB-20260824 |
| 92 | Combat Lab | Active skills | PASS | PHY-LAB-20260824 |
| 93 | Combat Lab | Pause and return to menu | PASS | PHY-LAB-20260824 |
