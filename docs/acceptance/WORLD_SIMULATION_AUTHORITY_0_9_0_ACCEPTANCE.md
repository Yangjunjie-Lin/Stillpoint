# Stillpoint 0.9.0 World Identity & Simulation Authority Acceptance

## Baseline and scope

- Fetched integration baseline: `develop`
- Baseline commit: `a926c0ab8cda159d1f32c73ec0113741cc659cec`
- Implementation branch: `feat/0.9.0-world-simulation-authority`
- Scope: product/domain/authority documentation and one `TalkIntent` pilot
- Explicitly excluded: 0.10.0 camera/combat expansion and later world systems

## Automated gate

Completed locally on Godot 4.7.1:

```text
Godot unit/integration: 351 passed, 0 failed
Unexpected SCRIPT ERROR: 0
Unexpected ERROR: 0
ObjectDB leaks: 0
Resource leaks: 0

NPC Mind (in-memory applicable): 250 passed, 8 PostgreSQL-only skipped
Ruff: passed
NPC cognition contract: passed
Cognition catalog check: 9 NPC profiles, 3 pet profiles
Repository validation: passed
```

The Godot suite includes existing coverage for authored/free-form dialogue,
offline fallback, pet autonomy and advisory authority, farming Save/Continue,
commerce/property/banking, dungeon progression/loot, combat, regions, quests,
relationships, runtime entities, Save v4 recovery, and the legacy survival mode.
It also verifies that Combat Lab diagnostics render runtime values without
formatting errors in a Debug Build.

New authority tests prove:

- intent/proposal objects have no `apply` or `execute` behavior;
- LLM, deterministic-AI, system, impersonated, unloaded, cross-region,
  unavailable, out-of-range, and unsupported proposals cannot run an authored
  Effect, open dialogue, or emit `NPC_TALKED`;
- Conditions and validation form one final authorization boundary before Effects;
- an Effect may move the actor out of range after authorization without causing
  the old post-Effect revalidation/partial-rejection bug;
- required Effect failure and dialogue-start failure emit no `NPC_TALKED`;
- existing `WorldEffect.apply_sequence()` no-rollback semantics are explicit;
- a consumed session-local proposal ID cannot replay Effects or money changes;
- successful player-input talk opens exactly once and emits exactly one event
  with proposal/source/actor/target provenance.

## Interactive reviewer checklist

This checklist is intentionally not marked complete by the headless automated
run. Complete it in a Debug Build before merging to `develop`:

1. Start **New Adventure** and confirm movement, interaction prompts, HUD, and
   region visuals load without errors.
2. Talk to a spawned service NPC (bank clerk or blacksmith). Confirm dialogue
   opens, the actor pauses, choices work, and closing restores control.
3. With AI disabled, confirm deterministic dialogue still works. With a local
   backend enabled, confirm free-form NPC dialogue works and a backend failure
   falls back without blocking gameplay.
4. Confirm pet follow/stay/explore behavior, pet menu/equipment, and optional AI
   advice failure do not stop local autonomy.
5. Travel to farmland; till, plant, water, rest, and harvest a crop.
6. Buy/sell/forge an item and use bank/home storage or funds. Confirm balances
   and items change exactly once.
7. Enter the dungeon through its gate, fight, receive loot/progression, and
   return to the wilderness.
8. Open Combat Lab and confirm combo, guard, skill/hit, knockback, and pause
   return behavior.
9. Save, exit to the main menu, Continue, and confirm player build, inventory,
   equipment, finances/property, farm/region state, quests/relationships, pet
   state, cognition cache, and dungeon state persist.
10. Confirm the README's Implemented / Experimental / Planned labels match what
    was observed. Do not begin 0.10.0 until this checklist is signed off.

## Gate status

Automated gate: **passed**.

Interactive reviewer gate: **pending review**.

Promotion to `develop`, release stabilization, and 0.10.0 work remain blocked
on that explicit interactive acceptance rather than being inferred from the
headless test result.
