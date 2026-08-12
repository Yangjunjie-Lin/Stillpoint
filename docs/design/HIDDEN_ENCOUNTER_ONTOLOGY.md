# Hidden Encounter Ontology

Stillpoint's hidden encounters are authored, deterministic opportunities that may
become eligible after a completed autonomous NPC dialogue turn or a committed,
player-initiated physical world action. Authored dialogue presentation, passive
system events, and failed/degraded AI replies never roll an encounter. They
reward items, equipment, materials, or skill books without giving the player or
NPCs advance access to the trigger rules.

## Runtime model

Each `EncounterDefinition` chooses either `autonomous_dialogue` or
`player_world_action` as its trigger kind, plus a repeat policy, visibility
policy, conditions, hidden probability, and an ordered reward-effect sequence.
Conditions reuse the read-only `WorldCondition` system. Rewards reuse
`WorldEffect.apply_sequence_once`, so a full backpack can block a later reward
without replaying an earlier successful reward. The pending reward remains
retryable and the encounter is completed only after every required effect
succeeds.

The probability roll is deterministic for the installed player profile,
encounter, authored salt, triggering fact, world day, and eligible-attempt count.
Save/Continue therefore cannot reroll the same attempt by restarting the game.
Runtime state lives in `global_world.hidden_encounters` under Save v4 and is
bounded and sanitized during restore.

## Knowledge boundary

The generated catalog keeps `hidden_encounter_ontology` separate from canonical
`world_ontology`. It contains enough server-owned metadata to validate and
materialize a discovery, but omits probability, salts, exact conditions, and
concrete reward effects. Undiscovered encounter nodes and their `INVOLVES`,
`DISCOVERED_IN`, and `MAY_REWARD` edges never enter the canonical world graph.

An `encounter_discovered` gameplay fact is emitted only after reward completion.
The autonomous-dialogue trigger fact contains request provenance but deliberately
contains neither the player's prompt nor the NPC's reply. World-action facts must
be emitted only after the action commits and must carry runtime-owned
`player_initiated` and `action_committed` markers.
For `WITNESSED` encounters, the normal region, distance, line-of-sight, and
participant checks decide which NPC instance receives the fact. The backend then
materializes the encounter node and public relationships only inside that NPC's
scoped graph, with its memory as evidence. Other NPCs do not learn it
automatically. `PLAYER_PRIVATE` exploration discoveries create no NPC outbox
entry; an NPC can learn them later only through an explicit witnessed or told
fact.

## Initial authored encounters

- The Warden's Quiet Needle: a dialogue discovery involving Warden Aster that
  can reward Aster's Quiet Compass.
- Moonleaf Hush: a private night-foraging discovery in Greywake Wilds that can
  reward Greywake Moonleaf.
- Lesson of the Fallen Guard: a private deep-dungeon discovery that can reward a
  guarding skill book.

Skill books are regular item definitions. Using one atomically consumes it and
adds authored proficiency points to its target skill, unless that skill is
already at its cap.
