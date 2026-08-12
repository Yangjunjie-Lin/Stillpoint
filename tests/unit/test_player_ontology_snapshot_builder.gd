extends RefCounted


func run() -> bool:
	var player := PlayerController3D.new()
	player.origin_id = &"lotus_ascetic"
	player.selected_faction_id = &"ash_watch"
	player.profession_id = &"duelist"
	player.attribute_seed = 24_681_357
	# This mutable runtime copy must never be serialized by the ontology builder.
	player.attribute_points = {"private_exact_value": 999}
	player.appearance_options = {
		"body_id": "sturdy",
		"skin_id": "deep",
		"hair_id": "short",
		"headwear_id": "none",
		"palette_id": "ember",
		"accessory_id": "not_an_authored_option",
	}
	var snapshot := PlayerOntologySnapshotBuilder.build(
		player,
		"  Observer\nName That Is Deliberately Too Long  ",
	)
	player.free()

	var identity: Dictionary = snapshot.get("public_identity", {})
	var appearance: Dictionary = snapshot.get("visible_appearance", {})
	var loadout: Dictionary = snapshot.get("visible_loadout", {})
	var capabilities: Array = snapshot.get("observable_capabilities", [])
	var capability_ids: Array[String] = []
	var capabilities_valid := capabilities.size() <= 6
	for capability: Variant in capabilities:
		if not capability is Dictionary:
			capabilities_valid = false
			continue
		var item := capability as Dictionary
		capabilities_valid = capabilities_valid and item.keys().size() == 3
		capabilities_valid = capabilities_valid and str(item.get("visibility", "")) == "public"
		capabilities_valid = capabilities_valid and str(item.get("evidence", "")) in [
			"faction", "profession", "observable_build",
		]
		capability_ids.append(str(item.get("trait_id", "")))

	var serialized := JSON.stringify(snapshot)
	var ok: bool = (
		int(snapshot.get("schema_version", 0)) == 1
		and identity.get("display_name") == "Observer Name That Is De"
		and identity.get("origin_id") == "lotus_ascetic"
		and not str(identity.get("origin_label", "")).is_empty()
		and identity.get("faction_id") == "ash_watch"
		and not str(identity.get("faction_label", "")).is_empty()
		and identity.get("profession_id") == "duelist"
		and not str(identity.get("profession_label", "")).is_empty()
		and appearance == {
			"body_id": "sturdy",
			"skin_id": "deep",
			"hair_id": "short",
			"headwear_id": "none",
			"palette_id": "ember",
			"accessory_id": "none",
		}
		and loadout == {
			"main_hand_form": "empty",
			"off_hand_form": "empty",
			"dual_wielding": false,
			"load_posture": "balanced",
			"presentation": "plain",
		}
		and capabilities_valid
		and capability_ids.has("guarded")
		and capability_ids.has("forceful")
		and not serialized.contains("attribute_seed")
		and not serialized.contains("attribute_points")
		and not serialized.contains("private_exact_value")
		and not serialized.contains("24681357")
		and not serialized.contains("inventory")
		and not serialized.contains("equipment")
		and not serialized.contains("active_slots")
		and not serialized.contains("max_health_bonus")
		and not serialized.contains("attack_bonus")
	)
	if not ok:
		push_error("Player ontology snapshot was unbounded, incomplete, or exposed private stats")
	return ok
