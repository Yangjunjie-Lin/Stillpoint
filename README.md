# Stillpoint

> An AI-native persistent isekai living-world action RPG where characters,
> economies, factions, and territories evolve through systemic simulation.

Stillpoint is a playable Godot prototype aimed at the fantasy: **"I have
genuinely entered another world."** Version 0.9.0 establishes one product
identity, one domain language, and a deterministic authority boundary for
future world simulation. It does not claim that the full living world is
already complete.

## Current status

### Implemented

- Godot 4.7.1, Jolt Physics, a persistent `WorldSession`, and streamed region
  scenes for town, farmland, wilderness, a private home, and a dungeon.
- Save v4 with validation, backups, per-region chunks, runtime actor snapshots,
  permanent destruction, and Main Menu → Continue restore.
- 3D movement; animation-event melee combos; guard, skills, hit reactions,
  knockback, equipment, inventory, character builds, and proficiency.
- Authored and free-form NPC dialogue, quests, relationships, local schedules,
  persistent scoped memory, bounded knowledge/belief graphs, and deterministic
  offline dialogue fallback.
- Farming with till/plant/water/harvest/rest; private housing and storage;
  wallet/bank/home cash; fixed-price trade, equipment commerce, and forging;
  dungeon gating, loot, bosses, and respawn progression.
- Persistent pet companions with per-instance state, equipment, routines,
  autonomous local/off-screen behavior, and optional LLM movement advice that
  cannot choose coordinates or execute gameplay.
- A typed-intent boundary. The 0.9.0 pilot routes player-initiated `TalkIntent`
  through `IntentProposal` → `WorldIntentValidator` →
  `WorldIntentExecutor` → `GameplayEvent`.

### Experimental or partial

- NPC cognition uses a Stillpoint-owned FastAPI backend with PostgreSQL,
  pgvector, provider-independent structured output, privacy controls, and an
  in-memory test repository. Provider output remains advisory.
- Farming is a coherent single-crop loop, not a broad agriculture simulation.
- Commerce and banking are real and persistent, but prices are fixed and there
  is no conserved multi-business supply/demand economy yet.
- Housing supports deeds, custody, storage, reconstruction, and repossession,
  but not settlement-scale property markets.
- `WorldSimulationService` is a virtual-simulation hook; full regional and
  strategic simulation is not implemented.
- Hidden encounters and pet personality assessment are bounded vertical slices.

### Planned

- First/third-person action camera, lock-on, dodge, parry, poise, heavy attacks,
  and production animation foundations (0.10.0).
- Shared per-actor wallets, NPC inventories/equipment, professions, jobs,
  workplaces, wages, and production (0.11.0–0.12.0).
- Runtime factions, territory, governance, laws, and political offices (0.13.0).
- Simulation LOD, bounded catch-up, regional economy/conflict, multi-origin
  content, broader life systems, emergent history, and production visuals
  (0.14.0 onward).

The milestone sequence and gates are in [docs/ROADMAP.md](docs/ROADMAP.md).

## Architectural law

The LLM is never world authority.

```text
observed world/NPC state
→ decision layer
→ attributed typed intent
→ deterministic validation
→ simulation-owned execution
→ GameplayEvent
→ canonical state / Save v4
```

Provider text, memories, graph candidates, or SQL rows cannot directly grant
gold, create items, equip actors, change factions, kill entities, complete
quests, teleport actors, or set world flags. See
[docs/SIMULATION_AUTHORITY.md](docs/SIMULATION_AUTHORITY.md) and
[docs/LLM_WORLD_BOUNDARY.md](docs/LLM_WORLD_BOUNDARY.md).

## Playable modes

| Menu | Scene | Status |
| --- | --- | --- |
| New Adventure / Continue | `scenes/world/world_session.tscn` | Primary 2.5D living-world slice |
| Combat Lab | `scenes/combat/combat_lab.tscn` | 3D combat sandbox |
| Survival Prototype | `scenes/gameplay/gameplay.tscn` | Legacy 2D shooter, quarantined compatibility mode |

## Controls

| Action | Default |
| --- | --- |
| Move | WASD |
| Interact | F |
| Walk/run toggle | Space |
| Attack / three-hit combo | J |
| Jump | K |
| Guard | Shift |
| Crouch | Ctrl |
| Backpack / equipment | Tab |
| Use or equip selected item | X |
| Select hotbar slot | 1–9, Q / E, mouse wheel |
| Active skills | U / I / O / L |
| Pause / return menu | Esc |
| Combat diagnostics | F10 |

## Run and test

On Windows, double-click `START_STILLPOINT.cmd`; see
[docs/WINDOWS_QUICK_START.md](docs/WINDOWS_QUICK_START.md). The backend is
optional for ordinary gameplay and deterministic dialogue fallback.

```bash
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/test_runner.gd
python tools/python/run_godot_tests.py
python tools/python/validate_repo.py
```

The automated Godot gate discovers 351 unit/integration scripts and rejects
unexpected script errors, runtime errors, ObjectDB leaks, and resource leaks.
Backend tests cover the in-memory service and PostgreSQL/pgvector integration.

## Architecture map

- [Product vision](docs/PRODUCT_VISION.md)
- [Domain model](docs/DOMAIN_MODEL.md)
- [World simulation model](docs/WORLD_SIMULATION_MODEL.md)
- [Simulation authority](docs/SIMULATION_AUTHORITY.md)
- [LLM/world boundary](docs/LLM_WORLD_BOUNDARY.md)
- [Existing system inventory](docs/SYSTEM_INVENTORY.md)
- [Roadmap](docs/ROADMAP.md)
- [World/session implementation](docs/WORLD_ARCHITECTURE.md)
- [Save v4](docs/SAVE_V4_GUIDE.md)
