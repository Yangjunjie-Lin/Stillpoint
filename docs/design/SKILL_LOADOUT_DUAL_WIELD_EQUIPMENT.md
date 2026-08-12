# Skill Loadout, Dual Wield and Equipment

## Skill configuration

The player owns four active-skill slots, bound by the rebindable
`skill_slot_1` through `skill_slot_4` actions. At most three configured skills
may be offensive. Each active skill declares the main-hand and/or off-hand
forms it accepts, so changing the equipped weapon or selected 1–9 item changes
which actions are available without changing the skill definition.

Passive skills never occupy a slot. They activate from authored region and
proficiency conditions. Skill configuration persists in the Save v4 player
section; absent loadout data restores the safe default four-slot loadout.

## Hands

The equipped `WEAPON` is the main hand. The selected 1–9 inventory item becomes
the off hand when it is one-handed and exposes a hand form. If no main-hand
weapon is equipped, that same selected item remains the single held item for
legacy tool and farming interactions. Two-handed main-hand items suppress the
off hand. Both visible models use the shared item ontology and grip poses.

## Equipment

Attribute equipment includes weapon, chest/top, head, trousers, shoes, gloves,
bracers, two rings and belt. It contributes weight and may declare level,
strength and vitality requirements. Equipping remains permissive; exceeding
capacity or requirements produces a bounded overload ratio that reduces
attack, defense, energy recovery and movement. This makes unusual builds
possible while giving heavy equipment a real consequence.

Decorative head, body, hand, foot and ornament slots have no physical or level
constraint and contribute charisma. Existing stat-bearing charms remain
attribute equipment; authored decorative items do not add combat attributes.

## NPC observability

NPC cognition receives only bounded visible cues: hand forms, whether the
player is dual wielding, balanced/strained load posture and plain/notable/ornate
presentation. Exact equipment, inventory, skill slots, strength, vitality,
charisma and load values remain private. NPCs learn specific abilities through
normal observation or player dialogue, never from omniscient state access.
