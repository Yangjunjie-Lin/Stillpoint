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

New Adventures grant the three initial Pip equipment items. `Trail Snack` and
`Turnip` are suitable foods. Companion equipment and food remain ordinary backpack
items until the player uses them from the companion sheet.

Pet gear modifiers are program-authoritative. The Mosswoven Harness reduces real
incoming damage, the Quiet Bell Charm improves deterministic stamina recovery while
resting, and any authored attack or movement bonuses are applied only by the pet
controller. Equipment IDs persist in Save v4; modifier values are always resolved
again from the trusted item catalog.

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

Defeat, recovery, monster experience, life-skill proficiency, equipment, routine,
condition, and dialogue preferences are persisted in the `companions` Save v4
section. Legacy placeholder pet saves migrate into the new companion state without
discarding follow mode or bond.

## Manual acceptance

Use a real Debug Build and the normal backend; do not substitute a fake gateway.

1. Start a new Adventure and confirm Pip, Bastion, and Nimbus are visibly distinct,
   face their direction of travel, and each opens its own companion sheet with `F`.
2. Feed Pip and verify exactly one backpack item is consumed and hunger/mood/bond
   change only by the authored values.
3. Equip each starter item, confirm collar/body/charm appear on Pip, then unequip and
   confirm every item returns to the backpack.
4. Toggle following off, select each lifestyle and stay location, leave and return,
   and verify the selected routine is retained.
5. Advance game time and verify needs and the lifestyle's life skill progress.
6. Re-enable following and enter a hostile area. Verify Pip selects only actual
   hostile actors, spends stamina, can take damage, and gains pet experience only
   when credited with a defeat.
7. Enable AI Dialogue and talk to Pip. Verify a non-empty structured reply uses Pip's
   tone and that an NPC dialogue in flight cannot consume the pet reply.
8. Disable the per-pet proactive switch and verify Pip does not initiate dialogue;
   re-enable it and verify any proactive line is presented as Pip's speech rather
   than stored as a player message.
9. Save, exit, restart the backend and game, then Continue. Verify condition,
   progression, equipment, routine, stay location, and pet-specific memory remain.
10. Stop the backend and repeat care, equipment, movement, combat, save, and Continue.
    Gameplay must remain available and free dialogue must return a safe fallback
    without writing invalid memory or state.
