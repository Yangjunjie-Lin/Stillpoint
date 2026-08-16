# Stillpoint Product Vision

## Identity

**Stillpoint is an AI-native persistent isekai living-world action RPG where
characters, economies, factions, and territories continue to evolve through
systemic simulation.**

中文定位：**AI 原生、持久化、系统驱动的异世界生活模拟动作 RPG。**

The central fantasy is: **"I have genuinely entered another world."** The
world is not a theme park waiting for the player. Its actors have identities,
limited knowledge, goals, relationships, professions, possessions, schedules,
and consequences which can persist without direct player involvement.

"AI-native" means cognition can enrich decisions, expression, memory
retrieval, and narration. It never means that an LLM owns gameplay truth.

## Six equal pillars

1. **Action RPG combat** — responsive, readable, execution-driven real-time
   combat with build and weapon differences, not tab targeting.
2. **Isekai life simulation** — peaceful, commercial, social, criminal,
   professional, and exploratory lives are valid paths alongside combat.
3. **Autonomous NPC society** — NPC behavior arises from state, capability,
   knowledge, needs, relationships, opportunities, and bounded reasoning.
4. **Factions, territory, and politics** — real actors hold offices, real
   factions control places, and policies consume resources and cause effects.
5. **Persistent living world** — ownership, death, wealth, memory, work,
   politics, markets, and history survive Save/Continue and player absence.
6. **Exploration and discovery** — regions, cultures, danger, resources,
   dungeons, encounters, and origins create materially different journeys.

No pillar exists only as flavor text. Each completed feature must connect to
canonical rules and durable state where appropriate.

## Product principles

- **Causal consistency over feature count.** Twenty connected systems create a
  more convincing world than two hundred isolated minigames.
- **Player/NPC symmetry.** Prefer actor capabilities such as inventory,
  equipment, wallet, stats, skills, faction, and property over separate
  player-only and NPC-only rule engines.
- **Finite causes.** Items, money, labor, resources, authority, knowledge,
  time, and distance have explicit sources, sinks, or transfer paths.
- **Limited knowledge.** Canonical truth and an actor's beliefs are different.
- **Persistent identity.** Mutable state belongs to a persistent instance, not
  a reusable definition resource.
- **Simulation LOD.** Physical actors are for loaded spaces; unloaded actors
  use bounded abstract simulation.
- **Playable milestones.** Every phase preserves earlier features, adds tests,
  and passes manual acceptance before the next phase starts.

## Meaning of status labels

- **Implemented** — present in the playable primary world path, persisted or
  bounded as documented, and covered by automated tests.
- **Experimental/partial** — a working vertical slice or architectural hook
  that does not yet fulfill the final product fantasy at world scale.
- **Planned** — intentionally absent. Documentation must not imply it exists.

The current repository status is recorded in
[SYSTEM_INVENTORY.md](SYSTEM_INVENTORY.md). The ordered delivery plan is
[ROADMAP.md](ROADMAP.md).

## 1.0 proof, not infinity

Stillpoint 1.0 proves the fantasy in one deep vertical world: three factions,
three starting areas and settlements, six professions, three dungeons,
important persistent actors plus virtual secondary actors, one contested
territory, a functioning production chain, political and economic pressure,
peaceful and combat careers, and Save/Continue with retained consequences.

It does not require an enormous map or infinite generated content.
