extends RefCounted


func run() -> bool:
	for origin in ResourceRegistry.get_all_origins():
		var profession := ResourceRegistry.get_profession(origin.recommended_profession_id)
		if profession == null:
			push_error(
				"Origin %s recommends missing profession %s"
				% [String(origin.id), String(origin.recommended_profession_id)]
			)
			return false
		if not profession.recommended_origin_ids.has(origin.id):
			push_error("Profession recommendation is not reciprocal for %s" % String(origin.id))
			return false
		var faction := ResourceRegistry.get_faction(origin.recommended_faction_id)
		if faction == null or not faction.selectable:
			push_error(
				"Origin %s recommends unavailable faction %s"
				% [String(origin.id), String(origin.recommended_faction_id)]
			)
			return false
	return true
