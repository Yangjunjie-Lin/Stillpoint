extends RefCounted


func run() -> bool:
	var expected_origins: Array[StringName] = [
		&"dune_ranger",
		&"lotus_ascetic",
		&"oathbound_knight",
		&"ronin",
		&"steppe_rider",
		&"wuxia_swordsman",
	]
	var expected_professions: Array[StringName] = [
		&"duelist",
		&"guardian",
		&"pathfinder",
		&"spirit_blade",
		&"vow_keeper",
		&"wind_scout",
	]
	var expected_factions: Array[StringName] = [
		&"ash_watch",
		&"dawn_covenant",
		&"free_roads",
		&"verdant_circle",
	]

	if ResourceRegistry.get_all_origin_ids() != expected_origins:
		push_error("Unexpected origin catalog: %s" % [ResourceRegistry.get_all_origin_ids()])
		return false
	if ResourceRegistry.get_all_profession_ids() != expected_professions:
		push_error("Unexpected profession catalog: %s" % [ResourceRegistry.get_all_profession_ids()])
		return false

	var selectable_ids: Array[StringName] = []
	for faction in ResourceRegistry.get_selectable_factions():
		selectable_ids.append(faction.id)
	if selectable_ids != expected_factions:
		push_error("Unexpected selectable faction catalog: %s" % [selectable_ids])
		return false

	for origin in ResourceRegistry.get_all_origins():
		if origin.description.is_empty() or origin.appearance_description.is_empty():
			push_error("Origin lacks authored presentation text: %s" % String(origin.id))
			return false
	return true
