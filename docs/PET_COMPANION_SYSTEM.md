# Pet Companion System

Stillpoint companions are persistent world actors with their own authored ontology,
mutable runtime state, equipment, progression, daily routine, memory scope, and
first-person dialogue. The playable roster is catalog-driven rather than fixed to
one animal: Pip the Moss Fox, Bastion the Stone Hound, and Nimbus the Cloud Owl are
the initial authored types. Adding another valid resource under
`resources/pet_companions/` gives it an independent world instance and cognition
profile without changing the controller.

## Player controls

1. Start or continue an Adventure and approach any companion in the town.
2. Press `F` when `Care for <name>` is shown.
3. The companion sheet lets the player:
   - inspect level, experience, health, stamina, hunger, mood, bond, personality,
     life skills, and attack skills;
   - switch between following and independent living;
   - choose an authored lifestyle and preferred stay location;
   - feed one eligible item directly from the backpack;
   - equip or remove collar, body gear, and charm items through an atomic backpack
     exchange;
   - enable or disable proactive dialogue for this companion;
   - speak freely to the selected companion through its own cognition profile.

New Adventures grant the three initial Pip equipment items. The Stillpoint smithy
sells fitted guard equipment for Bastion and lightweight flight equipment for
Nimbus. `Trail Snack` and `Turnip` are suitable foods. Companion equipment and food
remain ordinary backpack items until the player uses them from the companion sheet.

Pet gear modifiers are program-authoritative. The Mosswoven Harness reduces real
incoming damage, the Quiet Bell Charm improves deterministic stamina recovery while
resting, and any authored attack or movement bonuses are applied only by the pet
controller. Equipment slots validate category, authored species fit, and weight;
fox, hound, and avian gear cannot be interchanged just because it shares a generic
collar/body/charm category. Equipment IDs persist in Save v4; modifier values are
always resolved again from the trusted item catalog.

## Authority boundary

The program owns movement, target selection, combat, damage, feeding, equipment,
progression, needs, routines, and all canonical ontology facts. The language model
may produce structured dialogue, bounded memory candidates, graph candidates, and
auditable suggestions. It cannot execute a suggested action or patch companion
state.

Pet cognition uses `entity_kind = pet`, a server-owned profile such as
`pet:mossfox`, `pet:stonehound`, or `pet:cloudowl`, and a persistent instance ID.
Memories and learned graph facts are isolated per pet
instance. A client-supplied identity or personality cannot replace the catalog
profile. Proactive dialogue is requested by the deterministic behavior controller,
uses a trusted `entity_proactive` context, and is never stored as if it were a
player utterance.

The backend companion profile is generated from the registered Godot resources by
`tools/godot/export_npc_cognition_catalog.gd`. Run the exporter after changing a
pet definition; CI invokes it with `--check` and fails when either the NPC or pet
catalog committed under `services/npc_mind/catalog/` is stale.

The Debug Build never contains a provider key. Configure the existing backend with
provider credentials through environment variables, then set
`NPC_BACKEND_URL=http://127.0.0.1:8443` for the client. The main Settings screen must
have `AI Dialogue` enabled for free or proactive pet dialogue. The global
`Pet May Start Conversations` setting and the per-pet switch must both be enabled
for proactive lines.

## Program-owned daily behavior

While following, each companion stays near the owner and may defend against program-confirmed
hostiles according to authored temperament, health, stamina, and mood. While not
following, the selected lifestyle constrains permitted activities such as resting,
foraging, guarding, exploring, and training. Game time advances needs and life-skill
practice. A pet assigned to another region is simulated off screen and appears again
when the player returns to its stay region.

### Context-aware autonomous movement

Companion wandering is a weighted decision rather than a shared patrol loop. The
program combines all of the following inputs for every pet:

- authored species traits and habitat affinities;
- the definition's authored personality traits;
- a small, stable variation derived from the pet's persistent instance ID, so two
  members of the same species need not move like clones;
- the current mood band (`happy`, `content`, `anxious`, or `sad`);
- program-owned scene semantics and safe behavior anchors in the active region;
- the player's selected lifestyle while the pet is living independently.

The result is deliberately recognizable without being perfectly repetitive. A moss
fox tends toward curious exploration and playful loops, a stone hound tends toward
following and cautious patrol, and a cloud owl tends toward perching and observation.
A happy pet is more likely to play, socialize, and explore; an anxious pet favors its
owner, patrol, or shelter; and a sad pet rests or remains near a trusted anchor more
often. Town favors social behavior, farmland and wilderness favor exploration,
dungeon semantics favor caution, and the player home favors sheltered rest. These
are tendencies rather than forced scripts, and an individual pet's stable variation
can visibly temper its species pattern.

The planner selects only program-authored candidates from the current active region.
Candidates are checked for finite coordinates, region ownership, hazard level, a
walkable ground hit, and a clear short path before use. If a pet makes no useful
progress for about 1.5 seconds, the route is discarded and planned again. A following
pet that is near the player may sniff, play, observe, or rest at a safe anchor within
the 5-metre owner leash; when the owner moves away, direct follow behavior takes
priority. Downed state, survival needs, combat, and distant following always override
soft autonomous wandering.

The current plan, deterministic random sequence, and decision counter are saved, so
Save/Continue does not reset every pet into the same first choice. Saved coordinates
are not trusted as movement authority: after loading, destinations are resolved from
the safe anchors in the current scene.

### LLM movement assessment boundary

When `AI Dialogue` is enabled, a dedicated low-priority gateway may call
`POST /v1/pets/movement-assessments`. An assessment is requested when the pet first
observes a movement context and when its mood crosses a mood-band boundary, its
region/scene semantics change, or its selected lifestyle changes. Ordinary waypoint
expiry is handled locally and does not call the provider again. Repeated equivalent
contexts are deduplicated, and backend cooldown and rate limits prevent per-frame or
per-waypoint provider traffic. The assessment gateway is separate from player-facing
NPC and pet dialogue, so background movement evaluation cannot consume a dialogue
reply.

The server injects the authoritative pet profile. The model can suggest only weights
for these allowlisted high-level motifs:

`idle_near_anchor`, `follow_owner`, `curious_explore`, `playful_loop`,
`social_approach`, `cautious_patrol`, `perch_observe`, and `rest_sheltered`.

It may also suggest normalized `pace`, `roam`, and `confidence` values. Valid advice
can influence the program's existing weights by at most 25%, scaled down further by
confidence and degraded status. The model cannot supply coordinates, destinations,
paths, speeds, targets, attacks, teleports, equipment changes, schedules, or other
gameplay actions. Godot remains the sole authority for coordinates, route candidate
selection, navigation, collision checks, combat, and every emitted movement intent.
Unknown or extra fields, including nested motif keys, are rejected independently at
the HTTP gateway, assessment adapter, and final planner boundary.

When AI is disabled, the backend is unavailable, the provider times out, or an
assessment is invalid or rate-limited, pets continue moving with the deterministic
local species/personality/mood/scene/lifestyle policy. Provider failure therefore
cannot stop companion gameplay, create an unsafe destination, or bypass combat and
survival priorities.

For SiliconFlow/Qwen and other compatible providers configured with
`OPENAI_RESPONSE_FORMAT=text`, the assessment response is intentionally a strict one-line
protocol rather than free-form JSON:

```text
动作=守候|跟随|探索|玩耍|亲近|巡逻|观察|休息;节奏=慢|中|快;范围=近|中|远
```

An actual response uses one value for each field, for example
`动作=观察;节奏=中;范围=近。`. Only one trailing Chinese full stop is tolerated. Any
additional prose or field, including coordinates, targets, attacks, or teleport requests,
is rejected. The backend permits one corrective retry, then falls back to the local policy;
both calls count toward the usage budget. The three fields are translated into bounded
allowlisted motif/pace/roam preferences and cannot directly select a destination or move a
pet. This keeps Qwen-compatible text generation useful while preserving the program-owned
movement boundary.

Defeat, recovery, monster experience, life-skill proficiency, equipment, routine,
condition, and dialogue preferences are persisted in the `companions` Save v4
section. Pet runtime state is currently section version 3; v2 saves migrate the
old broadly-compatible starter gear into the fitted fox, hound, or avian item
without discarding an equipped item. Legacy placeholder pet saves migrate into
the new companion state without discarding follow mode or bond.

## Manual acceptance

Use a real Debug Build and the normal backend; do not substitute a fake gateway.

1. Start a new Adventure and confirm Pip, Bastion, and Nimbus are visibly distinct,
   face their direction of travel, and each opens its own companion sheet with `F`.
2. Feed Pip and verify exactly one backpack item is consumed and hunger/mood/bond
   change only by the authored values.
3. Equip each starter item, confirm collar/body/charm appear on Pip, then unequip and
   confirm every item returns to the backpack.
4. Buy Bastion and Nimbus gear from Torren. Confirm the stone hound uses layered
   plates, the cloud owl uses a wing-root harness, and neither accepts another
   species' fitted gear.
5. Toggle following off, select each lifestyle and stay location, leave and return,
   and verify the selected routine is retained.
6. Advance game time and verify needs and the lifestyle's life skill progress.
7. Re-enable following and enter a hostile area. Verify Pip selects only actual
   hostile actors, spends stamina, can take damage, and gains pet experience only
   when credited with a defeat.
8. Enable AI Dialogue and talk to Pip. Verify a non-empty structured reply uses Pip's
   tone and that an NPC dialogue in flight cannot consume the pet reply.
9. Disable the per-pet proactive switch and verify Pip does not initiate dialogue;
   re-enable it and verify any proactive line is presented as Pip's speech rather
   than stored as a player message.
10. Save, exit, restart the backend and game, then Continue. Verify condition,
   progression, equipment, routine, stay location, and pet-specific memory remain.
11. Stop the backend and repeat care, equipment, movement, combat, save, and Continue.
    Gameplay must remain available and free dialogue must return a safe fallback
    without writing invalid memory or state.

### Motion observation checklist

Use normal gameplay controls and the companion sheet; do not edit save data or inject
coordinates. Keep the backend console visible when checking provider request timing.

1. In Town, enable `AI Dialogue`, set Pip, Bastion, and Nimbus to follow, and remain
   near them for several planning cycles. Confirm their routes are not a synchronized
   loop: Pip should show more sniffing/exploration, Bastion more owner-oriented patrol,
   and Nimbus more observation/perch choices. Exact destinations are intentionally not
   asserted.
2. Walk far enough away to trigger direct following, then stop near several behavior
   anchors. Confirm each pet catches up and may resume bounded local motion without
   roaming outside the owner leash.
3. Turn following off and assign contrasting lifestyles such as home companion,
   guardian, and forager/explorer. Observe at least two plan changes for each pet and
   confirm the selected lifestyle changes the kinds of anchors it favors.
4. Visit Town, Farmland or Wilderness, the Dungeon, and Player Home. Confirm movement
   changes with the scene: social near town anchors, exploratory outdoors, cautious in
   the dungeon, and sheltered at home. A pet must never select an anchor from the
   unloaded region, walk through a blocking collider, or move to an ungrounded point.
5. Change mood through ordinary care, hunger, rest, and game-time mechanics until the
   companion sheet crosses a mood band. Confirm the current soft route is reconsidered:
   happy behavior becomes more active/social, while anxious or sad behavior becomes
   more owner-oriented, cautious, idle, or sheltered as appropriate.
6. Watch the backend access log during steps 3-5. Expect a request to
   `/v1/pets/movement-assessments` for a new context revision, but no request on every
   frame or ordinary waypoint. Repeating an unchanged context should be deduplicated.
   Do not log provider credentials or authorization headers.
7. Let a pet encounter a blocked route and confirm it abandons the stalled plan after
   roughly 1.5 seconds instead of pushing forever. In a hostile area, confirm combat,
   critical recovery, and distant owner following override the random route.
8. Save and Continue in the same scene. Confirm the companions retain distinct motion
   sequences and valid plans without trusting an obsolete or cross-region destination.
9. Stop the backend, then repeat follow, independent lifestyle, scene travel, and
   combat observations. All movement must continue under the local policy. Start the
   backend again and change mood, scene, or lifestyle; valid advisory behavior may
   resume without disrupting dialogue or taking control of navigation.
