extends RefCounted


const TEST_SEED: int = 91_827_364
const TEST_APPEARANCE: Dictionary = {
	"body_id": "slender",
	"skin_id": "olive",
	"hair_id": "topknot",
	"headwear_id": "travel_hood",
	"palette_id": "ocean",
	"accessory_id": "satchel",
}


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	GameManager.player_name = "Ontology Traveler"
	GameManager.pending_character_build = {
		"section_version": CharacterBuildCalculator.BUILD_SECTION_VERSION,
		"origin_id": "ronin",
		"faction_id": "verdant_circle",
		"profession_id": "wind_scout",
		"appearance": TEST_APPEARANCE.duplicate(true),
		"attribute_seed": TEST_SEED,
		"attribute_generation_version": CharacterBuildCalculator.ATTRIBUTE_GENERATION_VERSION,
	}
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var before := PlayerOntologySnapshotBuilder.build(world.player, GameManager.player_name)
	var mira := WorldTestHelper.find_npc(world, "Mira")
	var first_payload := world.cognition_service.build_turn_payload(mira, "hello")
	var first_payload_snapshot: Dictionary = first_payload.get("player_ontology", {})
	var saved := world.save_world_state()
	world.free()
	await WorldTestHelper.await_frames(tree, 2)

	# Continue must restore the saved public identity instead of retaining this
	# deliberately stale process-global value.
	GameManager.player_name = "Wrong Process Name"
	GameManager.resume_requested = true
	var restored := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var after := PlayerOntologySnapshotBuilder.build(restored.player, GameManager.player_name)
	var restored_mira := WorldTestHelper.find_npc(restored, "Mira")
	var restored_payload := restored.cognition_service.build_turn_payload(
		restored_mira, "hello again"
	)
	var restored_payload_snapshot: Dictionary = restored_payload.get("player_ontology", {})
	var serialized := JSON.stringify(restored_payload_snapshot)
	var ok: bool = (
		saved
		and not before.is_empty()
		and before == first_payload_snapshot
		and before == after
		and after == restored_payload_snapshot
		and after.get("public_identity", {}).get("display_name") == "Ontology Traveler"
		and after.get("visible_appearance", {}) == {
			"body_id": "slender",
			"skin_id": "olive",
			"hair_id": "topknot",
			"headwear_id": "travel_hood",
			"palette_id": "ocean",
			"accessory_id": "satchel",
		}
		and not serialized.contains("attribute_seed")
		and not serialized.contains("attribute_points")
		and not serialized.contains(str(TEST_SEED))
		and not serialized.contains("inventory")
		and not serialized.contains("equipment")
		and not serialized.contains("active_slots")
	)
	GameManager.resume_requested = false
	restored.free()
	if not ok:
		push_error("NPC turn payload did not preserve a private, stable player ontology")
	return ok
