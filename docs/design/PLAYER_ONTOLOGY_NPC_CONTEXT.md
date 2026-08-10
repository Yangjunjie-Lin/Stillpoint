# Player Ontology in NPC Dialogue

The player ontology is a versioned, bounded snapshot of what an NPC may reasonably
observe or treat as public during a conversation. It is generated from the active
`PlayerController3D` character build and sent as `player_ontology` with each optional
AI dialogue turn.

## Knowledge boundaries

The shared public snapshot contains:

- player display name;
- origin, faction, and profession IDs plus authored labels;
- normalized body, skin, hair, headwear, palette, and accessory choices;
- qualitative capability tendencies such as `agile`, `guarded`, or `focused`.

It deliberately excludes:

- `attribute_seed` and the random point allocation;
- exact health, energy, attack, defense, speed, or regeneration values;
- inventory, equipment, private history, and unrevealed dialogue facts.

Origin is treated as a visible/public character-build cue, not permission to infer a
real-world ethnicity, religion, private belief, or complete biography. Capability
tendencies are descriptive dialogue context and are never authoritative gameplay
stats.

## NPC knowledge model

Public and learned knowledge have different ownership:

```text
Character build
  -> PlayerOntologySnapshotBuilder
  -> bounded public/visible request context
  -> available to the NPC in the current turn

Player disclosure in dialogue
  -> validated memory candidate
  -> (player_profile_id, world_save_id, npc_persistent_id)
  -> private recall by that NPC instance only
```

The snapshot is not written into the canonical knowledge graph or stored as a new
memory every turn. A fact learned by `bandit_0001` does not become knowledge owned by
`bandit_0002`. When Memory Personalization is disabled, dialogue facts are not written
to memory or the private graph.

## Trust model

The backend validates every ontology field using finite enums and length limits. It
still treats the snapshot as untrusted client data and places it in an explicit data
block for structured, generic-text, and Qwen provider paths. The server-owned NPC
profile remains authoritative and replaces any client-supplied `npc_profile`.

LLM graph candidates keep the existing safeguards: allowed predicates, existing
nodes, current-turn memory evidence, and full player/save/NPC ownership scope. The
player ontology cannot create canonical nodes or edges and cannot execute gameplay
intents.

Requests without `player_ontology` remain valid for older saves and pending outbox
entries.
