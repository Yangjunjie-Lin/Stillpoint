extends RefCounted


func run() -> bool:
	var expected: Array[StringName] = [
		&"building:mira_apothecary",
		&"building:town_guardhouse",
		&"building:town_storehouse",
		&"building:wayfarer_inn",
	]
	var ok := ResourceRegistry.get_all_house_ids() == expected
	var seen: Dictionary = {}
	for house in ResourceRegistry.get_all_houses():
		ok = ok and house.is_valid()
		ok = ok and not seen.has(house.id)
		ok = ok and house.region_id == &"base:town"
		ok = ok and house.floor_count >= 1
		ok = ok and not house.material_tags.is_empty()
		var catalog := house.to_catalog_dict()
		ok = ok and String(catalog.get("node_id", "")) == String(house.id)
		ok = ok and String(catalog.get("node_type", "")) == "building"
		seen[house.id] = true
	var mira := ResourceRegistry.get_house(&"building:mira_apothecary")
	var guardhouse := ResourceRegistry.get_house(&"building:town_guardhouse")
	ok = ok and mira != null and &"mira" in mira.owner_npc_definition_ids
	ok = ok and mira != null and &"mira" in mira.worker_npc_definition_ids
	ok = ok and guardhouse != null and &"ren" in guardhouse.worker_npc_definition_ids
	if not ok:
		push_error("house definition catalog or ontology identity contract failed")
	return ok
