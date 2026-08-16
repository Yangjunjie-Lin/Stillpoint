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

Completed in a real Windows Debug Build using isolated Save v4 application data:

1. **PASS** — New Adventure, movement, interaction prompts, HUD, and region
   visuals loaded correctly (`artifacts/manual-acceptance-step1-world.png`).
2. **PASS** — Service-NPC dialogue opened, choices worked, and control was
   restored on close (`artifacts/manual-acceptance-step2-bank-dialogue.png`).
3. **PASS** — Authored dialogue worked with AI disabled, backend free-form
   dialogue worked online, and offline fallback preserved gameplay
   (`artifacts/manual-acceptance-step3-backend-reply.png`,
   `artifacts/manual-acceptance-step3-offline-fallback2.png`).
4. **PASS** — Pet menu/equipment, follow/stay/explore, and unavailable-AI
   fallback preserved local autonomy (`artifacts/manual-acceptance-step4-explore.png`).
5. **PASS** — Farmland till, plant, water, rest/day advance, and harvest all
   completed (`artifacts/manual-acceptance-step5-harvested.png`).
6. **PASS** — Buy, sell, bank deposit, ore purchase, and forge each changed
   items/balances exactly once (`artifacts/manual-acceptance-step6-forged-once.png`).
7. **PASS** — Dungeon gate, combat, loot/progression, and return portal worked
   (`artifacts/manual-acceptance-step7-loot-progression.png`).
8. **PASS** — Combat Lab combo, guard, active skill/hit, knockback, and
   pause/return worked; diagnostics showed runtime values without formatting
   placeholders (`artifacts/manual-acceptance-step8-fixed-debug.png`,
   `artifacts/manual-acceptance-step8-fixed-bandit-hit.png`).
9. **PASS** — Save, exit, Continue restored build, inventory, equipment,
   finances/property, farm/region, quests/relationships, pet state, cognition
   cache, and dungeon state (`artifacts/manual-acceptance-step9-fixed-restored.png`).
10. **PASS** — README Implemented / Experimental / Planned labels matched the
    observed Debug Build behavior.

## Gate status

Automated gate: **passed**.

Interactive reviewer gate: **10/10 PASS**.

Tested commit: `139628ba7a5f0796107e937342e83a8574a74850`

Test date/time: `2026-08-17 02:46:09 +08:00`

Godot: `4.7.1.stable.official.a13da4feb`

Evidence: non-sensitive local screenshots under `artifacts/manual-acceptance-*.png`.

The interactive acceptance is complete. Promotion still requires the exact
feature Head to pass GitHub Actions and final review before merge to `develop`.
