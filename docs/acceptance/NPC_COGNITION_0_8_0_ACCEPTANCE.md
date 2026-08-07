# Stillpoint 0.8.0 NPC Cognition Acceptance

Status: **INCOMPLETE — PR #6 MUST REMAIN DRAFT AND MUST NOT BE MERGED**

This report deliberately separates automated cross-process evidence from the required A16
interactive Debug Build acceptance. Automated E2E is not a substitute for the 30 manual steps.
No credential, token, Authorization header, private conversation, or database password is
recorded here.

## Acceptance Target

- Date/time zone: 2026-08-07, Asia/Shanghai
- Branch: `feat/0.8.0-npc-cognitive-foundation`
- Base at stabilization start: `fd63f1d93641c44cb18f0101ef81c238cd28a76d`
- Starting Head: `0eced1f1f93bf0710c8a07dc38ab05cda4a61ede`
- Current automated evidence Head: `85ceef2796cea92aa30cfd338ae77dab0e018151`
- Godot automated acceptance commit: `85ceef2796cea92aa30cfd338ae77dab0e018151`
- Backend automated acceptance commit: `85ceef2796cea92aa30cfd338ae77dab0e018151`
- Game version: `0.8.0`
- Save schema: `save_version = 4`
- NPC cognition section: `section_version = 1`

## Automated Pre-A16 Evidence

- Godot 4.7.1: 249 passed, 0 failed
- Unexpected SCRIPT ERROR / ERROR: 0 / 0
- ObjectDB / Resource leaks: 0 / 0
- Backend in-memory: 70 passed, 7 PostgreSQL-only skipped
- Backend PostgreSQL/pgvector: 77 passed
- Alembic downgrade base and upgrade head: passed
- Cross-process Godot → HTTP → Uvicorn → PostgreSQL E2E: passed
- Cross-process phases: seed, Backend restart recall, offline save, recovery/Ack flush
- Catalog: 3 profiles, passed
- Contract and repository validation: passed
- Linux and Windows Debug Export plus binary secret/source scan: passed (local release-closure artifacts)
- Evidence logs: `artifacts/npc-cognition-cross-process-e2e/` (local, intentionally untracked)

## Manual A16 — 30 Required Steps

All rows below are intentionally `NOT RUN`. A human operator must replace each status with
`PASS` or `FAIL`, add the actual timestamp and commit SHA, describe the observed result, and
provide a non-sensitive log/screenshot location. Until every row is `PASS`, A16 is incomplete.

| # | Status | Date/time | Operation | Expected result | Actual result | Log/evidence |
|---:|---|---|---|---|---|---|
| 1 | NOT RUN | — | Start PostgreSQL | PostgreSQL/pgvector is ready | Awaiting manual run | — |
| 2 | NOT RUN | — | Run Alembic upgrade | Schema reaches head without error | Awaiting manual run | — |
| 3 | NOT RUN | — | Start Uvicorn Backend | Loopback health endpoint is ready | Awaiting manual run | — |
| 4 | NOT RUN | — | Start Godot Debug Build | World starts on the acceptance commit | Awaiting manual run | — |
| 5 | NOT RUN | — | Enable AI Dialogue in Settings UI | Setting is visibly enabled | Awaiting manual run | — |
| 6 | NOT RUN | — | Enable Conversation Storage | Setting is visibly enabled | Awaiting manual run | — |
| 7 | NOT RUN | — | Enable Memory Personalization | Setting is visibly enabled | Awaiting manual run | — |
| 8 | NOT RUN | — | Start normal deterministic dialogue with Mira | Authored dialogue remains functional | Awaiting manual run | — |
| 9 | NOT RUN | — | Click `Ask something else...` | Free-form input opens once | Awaiting manual run | — |
| 10 | NOT RUN | — | Enter the blue-preference memory sentence | One request is submitted | Awaiting manual run | — |
| 11 | NOT RUN | — | Observe the free-form reply | A real HTTP reply arrives | Awaiting manual run | — |
| 12 | NOT RUN | — | Check input submission | No duplicate submission occurs | Awaiting manual run | — |
| 13 | NOT RUN | — | Save and exit | Save v4 completes successfully | Awaiting manual run | — |
| 14 | NOT RUN | — | Stop Backend | Backend is fully stopped | Awaiting manual run | — |
| 15 | NOT RUN | — | Restart Backend | Backend returns healthy with the same database | Awaiting manual run | — |
| 16 | NOT RUN | — | Continue | Save v4 and cognition section restore | Awaiting manual run | — |
| 17 | NOT RUN | — | Ask color preference with different wording | Query is semantically different | Awaiting manual run | — |
| 18 | NOT RUN | — | Observe Mira recall | Mira recalls blue | Awaiting manual run | — |
| 19 | NOT RUN | — | Advance substantial game time | World time advances without corruption | Awaiting manual run | — |
| 20 | NOT RUN | — | Ask explicitly about the old event | Old high-salience memory remains retrievable | Awaiting manual run | — |
| 21 | NOT RUN | — | Compare old and ordinary memory weighting | Old salient memory remains; irrelevant memory decays | Awaiting manual run | — |
| 22 | NOT RUN | — | Tell `bandit_0001` a secret | Secret is stored for the real persistent instance | Awaiting manual run | — |
| 23 | NOT RUN | — | Speak with `bandit_0002` | Second real persistent instance is used | Awaiting manual run | — |
| 24 | NOT RUN | — | Ask `bandit_0002` about the secret | `bandit_0002` does not know it | Awaiting manual run | — |
| 25 | NOT RUN | — | Player attacks Mira | Gameplay event enters the cognition Outbox | Awaiting manual run | — |
| 26 | NOT RUN | — | Save, close, and restart | World and Backend state restore | Awaiting manual run | — |
| 27 | NOT RUN | — | Ask Mira about the attack | Mira recalls the attack event | Awaiting manual run | — |
| 28 | NOT RUN | — | Stop Backend and complete a Quest Dialogue | Deterministic Quest Dialogue remains functional | Awaiting manual run | — |
| 29 | NOT RUN | — | Verify reward, Save, and Continue | Reward is granted once; Save/Continue work | Awaiting manual run | — |
| 30 | NOT RUN | — | Inspect Linux/Windows exports | No Provider/Signing secret, Backend/Test/Tool source, or DB credential | Awaiting manual run | — |

## Real Provider Smoke

Status: **NOT RUN — required environment variables are unavailable in the current session.**

The non-CI smoke command is `python tools/python/run_npc_provider_smoke.py`. It records only
provider/model identifiers and boolean results for Structured Output, PostgreSQL `vector(1536)`,
timeout fallback, and Mira/Bandit differentiation. It never records prompts, replies, credentials,
or Authorization headers.

## Release Decision

- PR ready for review: **NO**
- A16 manual acceptance complete: **NO**
- Real Provider Smoke complete: **NO**
- Merge authorized: **NO**
