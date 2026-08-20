# Stillpoint 0.10.0 Action Camera and Combat Acceptance

Debug-build manual acceptance is separate from the automated suite. A row may
change from `NOT RUN` only after it is observed in a Windows Debug export built
from the candidate code. Automated coverage is supporting evidence, not a
substitute for this walkthrough.

## Execution record

- Status: **NOT RUN — walkthrough incomplete**
- Candidate Head at attempt time: uncommitted closure tree based on
  `61b63336e808e5156aaf8f883f69c4cd83f2c335`
- Attempted: 2026-08-21, Windows x86_64 Debug export
- Godot: 4.7.1.stable.official.a13da4feb
- Export SHA-256: `35BA3E89CBF18FE055DFC211D4E003786C43AB860BF4924EE87CD0E19ABD76E0`
- Automated gate: `355 passed, 0 failed`; unexpected script/runtime errors 0;
  ObjectDB/resource leaks 0
- Visual evidence: retained in the Codex release-closure task transcript

The attempt verified the 0.10.0 menu, camera settings layout, settings save,
New Adventure character creation, and entry into the third-person town scene.
It exposed and led to a fix for retained non-modal HUD focus suppressing camera
input. The fixed code passed the full automated gate and was re-exported. The
required rerun could not continue because the Windows computer-use controller
stopped delivering keyboard input and then failed recovery with
`failed to activate captured window`. No row below is claimed from that partial
attempt. The user's pre-existing save and settings were backed up and restored.

## Manual walkthrough

| # | Area | Check | Status | Evidence |
| ---: | --- | --- | --- | --- |
| 1 | Camera | Start New Adventure | NOT RUN | — |
| 2 | Camera | Third-person movement | NOT RUN | — |
| 3 | Camera | Rotate camera 360 degrees | NOT RUN | — |
| 4 | Camera | Walk/run in multiple camera orientations | NOT RUN | — |
| 5 | Camera | Camera collision against a wall | NOT RUN | — |
| 6 | Camera | Camera collision in a narrow interior | NOT RUN | — |
| 7 | Camera | Switch to first person | NOT RUN | — |
| 8 | Camera | First-person horizontal look | NOT RUN | — |
| 9 | Camera | First-person vertical look | NOT RUN | — |
| 10 | Camera | First-person walk/run/jump/crouch | NOT RUN | — |
| 11 | Camera | Repeated FP/TP switching | NOT RUN | — |
| 12 | Camera | Shoulder swap | NOT RUN | — |
| 13 | Camera | FOV and sensitivity settings | NOT RUN | — |
| 14 | Camera | Open and close pause | NOT RUN | — |
| 15 | Camera | Open and close inventory | NOT RUN | — |
| 16 | Camera | Mouse capture restores after modal UI | NOT RUN | — |
| 17 | Targeting | Lock a valid enemy | NOT RUN | — |
| 18 | Targeting | Strafe around the locked enemy | NOT RUN | — |
| 19 | Targeting | Cycle targets deterministically | NOT RUN | — |
| 20 | Targeting | Briefly obscure target | NOT RUN | — |
| 21 | Targeting | LOS grace retains then expires lock | NOT RUN | — |
| 22 | Targeting | Target outside range clears lock | NOT RUN | — |
| 23 | Targeting | Kill locked target | NOT RUN | — |
| 24 | Targeting | Dead target lock clears | NOT RUN | — |
| 25 | Targeting | Enter first person while targeting | NOT RUN | — |
| 26 | Targeting | First-person targeting/free aim remains coherent | NOT RUN | — |
| 27 | Combat | Third-person light combo | NOT RUN | — |
| 28 | Combat | Third-person heavy attack | NOT RUN | — |
| 29 | Combat | Normal guard | NOT RUN | — |
| 30 | Combat | Successful parry | NOT RUN | — |
| 31 | Combat | Failed parry timing becomes normal guard/damage | NOT RUN | — |
| 32 | Combat | Non-parryable attack cannot be parried | NOT RUN | — |
| 33 | Combat | Dodge forward | NOT RUN | — |
| 34 | Combat | Dodge backward | NOT RUN | — |
| 35 | Combat | Dodge sideways | NOT RUN | — |
| 36 | Combat | Damage rejected inside dodge iframe | NOT RUN | — |
| 37 | Combat | Damage applies outside dodge iframe | NOT RUN | — |
| 38 | Combat | Trigger poise break | NOT RUN | — |
| 39 | Combat | Observe stagger and recovery | NOT RUN | — |
| 40 | Combat | Observe hitstun and recovery | NOT RUN | — |
| 41 | Combat | Observe blockstun and recovery | NOT RUN | — |
| 42 | Combat | Verify knockback | NOT RUN | — |
| 43 | Combat | Use active skill | NOT RUN | — |
| 44 | First-person combat | Light attack | NOT RUN | — |
| 45 | First-person combat | Heavy attack | NOT RUN | — |
| 46 | First-person combat | Guard | NOT RUN | — |
| 47 | First-person combat | Parry | NOT RUN | — |
| 48 | First-person combat | Dodge | NOT RUN | — |
| 49 | First-person combat | Active skill | NOT RUN | — |
| 50 | First-person combat | Switch to third person in a safe combat state | NOT RUN | — |
| 51 | First-person combat | No duplicate damage or event after switch | NOT RUN | — |
| 52 | Living world | Authored NPC dialogue | NOT RUN | — |
| 53 | Living world | Free-form dialogue with Backend available | NOT RUN | — |
| 54 | Living world | Backend-offline dialogue fallback | NOT RUN | — |
| 55 | Living world | Pet follow/stay/explore | NOT RUN | — |
| 56 | Living world | Pet UI and equipment | NOT RUN | — |
| 57 | Living world | Farming | NOT RUN | — |
| 58 | Living world | Buy and sell | NOT RUN | — |
| 59 | Living world | Forge | NOT RUN | — |
| 60 | Living world | Bank and property | NOT RUN | — |
| 61 | Living world | Dungeon entry | NOT RUN | — |
| 62 | Living world | Dungeon combat | NOT RUN | — |
| 63 | Living world | Loot and progression | NOT RUN | — |
| 64 | Living world | Return from dungeon | NOT RUN | — |
| 65 | Save/Continue | Save during safe runtime state | NOT RUN | — |
| 66 | Save/Continue | Exit to menu | NOT RUN | — |
| 67 | Save/Continue | Continue | NOT RUN | — |
| 68 | Save/Continue | Character build preserved | NOT RUN | — |
| 69 | Save/Continue | Inventory preserved | NOT RUN | — |
| 70 | Save/Continue | Equipment preserved | NOT RUN | — |
| 71 | Save/Continue | Finances/property preserved | NOT RUN | — |
| 72 | Save/Continue | Farm and region state preserved | NOT RUN | — |
| 73 | Save/Continue | Quests and relationships preserved | NOT RUN | — |
| 74 | Save/Continue | Pet state preserved | NOT RUN | — |
| 75 | Save/Continue | Cognition state/cache policy preserved | NOT RUN | — |
| 76 | Save/Continue | Dungeon state preserved | NOT RUN | — |
| 77 | Save/Continue | Camera preference follows settings policy | NOT RUN | — |
| 78 | Save/Continue | No transient combat state restored | NOT RUN | — |
| 79 | Combat Lab | Open Combat Lab | NOT RUN | — |
| 80 | Combat Lab | Third-person camera | NOT RUN | — |
| 81 | Combat Lab | First-person camera | NOT RUN | — |
| 82 | Combat Lab | Camera collision | NOT RUN | — |
| 83 | Combat Lab | Target lock and cycling | NOT RUN | — |
| 84 | Combat Lab | Heavy attack | NOT RUN | — |
| 85 | Combat Lab | Guard | NOT RUN | — |
| 86 | Combat Lab | Successful parry | NOT RUN | — |
| 87 | Combat Lab | Failed/non-parryable parry cases | NOT RUN | — |
| 88 | Combat Lab | Dodge iframe | NOT RUN | — |
| 89 | Combat Lab | Poise and stagger | NOT RUN | — |
| 90 | Combat Lab | Hitstun and blockstun | NOT RUN | — |
| 91 | Combat Lab | Knockback | NOT RUN | — |
| 92 | Combat Lab | Active skills | NOT RUN | — |
| 93 | Combat Lab | Pause and return to menu | NOT RUN | — |
