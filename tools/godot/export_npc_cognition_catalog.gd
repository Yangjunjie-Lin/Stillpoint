extends SceneTree

const OUTPUT_PATH := "res://services/npc_mind/catalog/generated_npc_catalog.json"

func _initialize() -> void:
	call_deferred("_export_catalog")

func _export_catalog() -> void:
	await process_frame
	var errors: Array[String] = []
	var profiles: Array = []
	var mind_ids := {}
	var registry := root.get_node("ResourceRegistry")
	for npc: Variant in registry.call("get_all_npcs"):
		var mind: Variant = npc.get("mind_profile")
		if mind == null:
			errors.append("NPC '%s' has no mind_profile" % String(npc.get("id")))
			continue
		if not bool(mind.call("is_valid")):
			errors.append("NPC '%s' has an invalid mind_profile" % String(npc.get("id")))
			continue
		var mind_id: StringName = mind.get("id")
		if mind_ids.has(mind_id):
			errors.append("Duplicate mind_profile id '%s'" % String(mind_id))
			continue
		mind_ids[mind_id] = true
		var known_nodes := {}
		for seed: Variant in mind.get("knowledge_seeds"):
			if seed != null:
				known_nodes[seed.get("node_id")] = true
		for skill: Variant in mind.get("cognitive_skills"):
			if skill == null:
				continue
			for node_id: StringName in skill.get("knowledge_node_ids"):
				if not known_nodes.has(node_id):
					errors.append("NPC '%s' skill '%s' references unknown node '%s'" % [
						String(npc.get("id")), String(skill.get("id")), String(node_id),
					])
		var profile: Dictionary = mind.call("to_catalog_dict")
		profile["definition_id"] = String(npc.get("id"))
		profile["display_name"] = npc.get("display_name")
		profile["witness_radius"] = npc.get("witness_radius")
		profiles.append(profile)
	profiles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("definition_id", "")) < str(b.get("definition_id", "")))
	var world_ontology := _build_world_ontology(registry, errors)
	if not errors.is_empty():
		for message in errors:
			push_error("NPC catalog: %s" % message)
		quit(1)
		return
	var payload := {
		"catalog_version": 4,
		"game_version": "0.8.0",
		"npc_count": profiles.size(),
		"npcs": profiles,
		"world_ontology": world_ontology,
		"relation_action_catalog": KnowledgeActionLibrary.catalog(),
	}
	var rendered := JSON.stringify(payload, "  ") + "\n"
	var args := OS.get_cmdline_user_args()
	if "--check" in args:
		if not FileAccess.file_exists(OUTPUT_PATH):
			push_error("NPC catalog is missing: %s" % OUTPUT_PATH)
			quit(1)
			return
		var existing := FileAccess.get_file_as_string(OUTPUT_PATH)
		if existing != rendered:
			push_error("NPC catalog is stale; run export_npc_cognition_catalog.gd")
			quit(1)
			return
		print("NPC catalog validation: %d profiles" % profiles.size())
		quit(0)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	var file := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write NPC catalog")
		quit(1)
		return
	file.store_string(rendered)
	file.close()
	print("NPC catalog exported: %d profiles" % profiles.size())
	quit(0)


func _build_world_ontology(registry: Node, errors: Array[String]) -> Dictionary:
	var nodes: Dictionary = {}
	var edges: Dictionary = {}
	_add_world_node(nodes, "location:town_plaza", "location", "Stillpoint Town Plaza", {
		"region_id": "base:town",
		"location_type": "public_plaza",
	})
	for region: Variant in registry.call("get_all_regions"):
		var region_id := String(region.get("id"))
		var node_id := "region:%s" % region_id
		_add_world_node(nodes, node_id, "region", String(region.get("display_name")), {
			"region_id": region_id,
			"region_type": String(region.get("region_type")),
			"parent_world_id": String(region.get("parent_world_id")),
			"parent_region_id": String(region.get("parent_region_id")),
			"dungeon_id": String(region.get("dungeon_id")),
		})
		for target: StringName in region.get("connected_region_ids"):
			_add_world_edge(edges, node_id, "CONNECTED_TO", "region:%s" % String(target), region_id)
		for target: StringName in region.get("portal_region_ids"):
			_add_world_edge(edges, node_id, "PORTAL_TO", "region:%s" % String(target), region_id)
	for dungeon: Variant in registry.call("get_all_dungeons"):
		if not bool(dungeon.call("is_valid")):
			errors.append("Invalid dungeon definition '%s'" % String(dungeon.get("id")))
			continue
		var data := dungeon.call("to_catalog_dict") as Dictionary
		var dungeon_id := String(data.get("id", ""))
		var dungeon_node := "dungeon:%s" % dungeon_id
		var parent_region_node := "region:%s" % String(data.get("parent_region_id", ""))
		var dungeon_region_node := "region:%s" % String(data.get("region_id", ""))
		var entrance_node := String(data.get("entrance_location_id", ""))
		var guard_node := "npc_definition:%s" % String(data.get("guard_definition_id", ""))
		_add_world_node(nodes, dungeon_node, "location", String(data.get("display_name", dungeon_id)), {
			"dungeon_id": dungeon_id,
			"region_id": String(data.get("region_id", "")),
			"parent_region_id": String(data.get("parent_region_id", "")),
			"entry_level": int(data.get("entry_level", 1)),
			"max_depth": int(data.get("max_depth", 1)),
			"lore_tags": data.get("lore_tags", []),
		})
		_add_world_node(nodes, entrance_node, "location", "Warden's Threshold", {
			"location_type": "dungeon_gate",
			"dungeon_id": dungeon_id,
		})
		_add_world_node(nodes, guard_node, "npc_definition", _label_for_node(guard_node), {})
		_add_world_edge(edges, dungeon_node, "LOCATED_IN", parent_region_node, dungeon_id)
		_add_world_edge(edges, dungeon_node, "RELATED_TO", dungeon_region_node, dungeon_id)
		_add_world_edge(edges, entrance_node, "LOCATED_IN", parent_region_node, dungeon_id)
		_add_world_edge(edges, entrance_node, "CONNECTED_TO", dungeon_node, dungeon_id)
		_add_world_edge(edges, entrance_node, "GUARDED_BY", guard_node, dungeon_id)
		var floor_names: Array = data.get("floor_names", [])
		for index in floor_names.size():
			var depth := index + 1
			var floor_node := "location:%s:depth_%d" % [dungeon_id, depth]
			var required_level: int = int([1, 3, 5][mini(index, 2)])
			var level_node := "concept:combat_level_%d" % required_level
			_add_world_node(nodes, floor_node, "location", String(floor_names[index]), {
				"dungeon_id": dungeon_id,
				"depth": depth,
				"required_level": required_level,
			})
			_add_world_node(nodes, level_node, "concept", "Combat Level %d" % required_level, {})
			_add_world_edge(edges, dungeon_node, "HAS_DEPTH", floor_node, dungeon_id)
			_add_world_edge(edges, floor_node, "REQUIRES_LEVEL", level_node, dungeon_id)
		var boss_ids: Array = data.get("boss_definition_ids", [])
		for boss_id_variant in boss_ids:
			var boss_id := StringName(str(boss_id_variant))
			var boss: Variant = registry.call("get_npc", boss_id)
			if boss == null or String(boss.get("dungeon_boss_id")).is_empty():
				errors.append("Dungeon '%s' references invalid boss '%s'" % [dungeon_id, String(boss_id)])
				continue
			var boss_node := "npc_definition:%s" % String(boss_id)
			var depth := int(boss.get("dungeon_depth"))
			var floor_node := "location:%s:depth_%d" % [dungeon_id, depth]
			var respawn_node := "concept:respawn_days_%d" % int(boss.get("dungeon_respawn_days"))
			_add_world_node(nodes, boss_node, "npc_definition", String(boss.get("display_name")), {
				"boss_id": String(boss.get("dungeon_boss_id")),
				"depth": depth,
				"required_level": int(boss.get("dungeon_required_level")),
				"respawn_days": int(boss.get("dungeon_respawn_days")),
				"phase": String(boss.get("dungeon_phase")),
			})
			_add_world_node(nodes, respawn_node, "concept", "%d Day Return Cycle" % int(boss.get("dungeon_respawn_days")), {})
			_add_world_edge(edges, dungeon_node, "HAS_BOSS", boss_node, dungeon_id)
			_add_world_edge(edges, boss_node, "LOCATED_IN", floor_node, dungeon_id)
			_add_world_edge(edges, boss_node, "RESPAWNS_AFTER", respawn_node, dungeon_id)
	for crop: Variant in registry.call("get_all_crops"):
		if not bool(crop.call("is_valid")):
			errors.append("Invalid crop definition '%s'" % String(crop.get("id")))
			continue
		var crop_id := String(crop.get("id"))
		var crop_node := "crop:%s" % crop_id
		var seed_node := "item:%s" % String(crop.get("seed_item_id"))
		var produce_node := "item:%s" % String(crop.get("produce_item_id"))
		var region_node := "region:%s" % String(crop.get("soil_region_id"))
		_add_world_node(nodes, crop_node, "crop", String(crop.get("display_name")), {
			"watered_days_to_mature": int(crop.get("watered_days_to_mature")),
			"harvest_quantity": int(crop.get("harvest_quantity")),
		})
		_add_world_node(nodes, seed_node, "item", _label_for_node(seed_node), {})
		_add_world_node(nodes, produce_node, "item", _label_for_node(produce_node), {})
		_add_world_edge(edges, crop_node, "HAS_SEED", seed_node, crop_id)
		_add_world_edge(edges, crop_node, "PRODUCES", produce_node, crop_id)
		_add_world_edge(edges, crop_node, "GROWS_IN", region_node, crop_id)
	for house: Variant in registry.call("get_all_houses"):
		if not bool(house.call("is_valid")):
			errors.append("Invalid house definition '%s'" % String(house.get("id")))
			continue
		var data := house.call("to_catalog_dict") as Dictionary
		var house_id := String(data.get("node_id", ""))
		_add_world_node(
			nodes,
			house_id,
			"building",
			String(data.get("label", house_id)),
			data.get("metadata", {}) as Dictionary,
		)
		var region_node := "region:%s" % String(house.get("region_id"))
		_add_world_edge(edges, house_id, "LOCATED_IN", region_node, house_id)
		for npc_id: String in data.get("owner_npc_definition_ids", []):
			_add_world_edge(edges, "npc_definition:%s" % npc_id, "OWNS", house_id, house_id)
		for npc_id: String in data.get("resident_npc_definition_ids", []):
			_add_world_edge(edges, "npc_definition:%s" % npc_id, "LIVES_IN", house_id, house_id)
		for npc_id: String in data.get("worker_npc_definition_ids", []):
			_add_world_edge(edges, "npc_definition:%s" % npc_id, "WORKS_AT", house_id, house_id)
		for contained_id: String in data.get("contains_node_ids", []):
			_add_world_node(nodes, contained_id, _node_type(contained_id), _label_for_node(contained_id), {
				"contained_by": house_id,
			})
			_add_world_edge(edges, house_id, "CONTAINS", contained_id, house_id)
		for connected_id: String in data.get("connected_location_ids", []):
			_add_world_node(nodes, connected_id, _node_type(connected_id), _label_for_node(connected_id), {})
			_add_world_edge(edges, house_id, "CONNECTED_TO", connected_id, house_id)
		for linked_id: String in data.get("linked_location_ids", []):
			_add_world_node(nodes, linked_id, _node_type(linked_id), _label_for_node(linked_id), {})
			_add_world_edge(edges, house_id, "RELATED_TO", linked_id, house_id)
	for container: Variant in registry.call("get_all_containers"):
		if not bool(container.call("is_valid")):
			errors.append("Invalid container definition '%s'" % String(container.get("id")))
			continue
		var data := container.call("to_catalog_dict") as Dictionary
		var container_id := String(data.get("node_id", ""))
		_add_world_node(
			nodes,
			container_id,
			"container",
			String(data.get("label", container_id)),
			data.get("metadata", {}) as Dictionary,
		)
		var location_id := String(container.get("location_node_id"))
		var location_node := (
			location_id if not location_id.is_empty()
			else "region:%s" % String(container.get("region_id"))
		)
		_add_world_node(
			nodes,
			location_node,
			_node_type(location_node),
			_label_for_node(location_node),
			{},
		)
		_add_world_edge(edges, container_id, "LOCATED_IN", location_node, container_id)
		for content_id: String in data.get("public_contents_node_ids", []):
			_add_world_node(nodes, content_id, _node_type(content_id), _label_for_node(content_id), {})
			_add_world_edge(edges, container_id, "CONTAINS", content_id, container_id)
		var required_action := StringName(str(container.get("required_utility_action")))
		for item: Variant in registry.call("get_all_items"):
			if not bool(item.call("supports_utility_action", required_action)):
				continue
			var item_node := "item:%s" % String(item.get("id"))
			_add_world_node(nodes, item_node, "item", String(item.get("display_name")), {})
			_add_world_edge(edges, container_id, "OPENED_BY", item_node, container_id)
	var node_list: Array = nodes.values()
	var edge_list: Array = edges.values()
	node_list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("node_id", "")) < str(b.get("node_id", "")))
	edge_list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _edge_key(a) < _edge_key(b))
	return {"nodes": node_list, "edges": edge_list}


func _add_world_node(
	nodes: Dictionary,
	node_id: String,
	node_type: String,
	label: String,
	metadata: Dictionary,
) -> void:
	if node_id.is_empty() or nodes.has(node_id):
		return
	nodes[node_id] = {
		"node_id": node_id,
		"node_type": node_type,
		"label": label,
		"metadata": metadata,
		"visibility": "public",
		"source": "world_catalog",
	}


func _add_world_edge(
	edges: Dictionary,
	subject: String,
	predicate: String,
	object_id: String,
	source_id: String,
) -> void:
	var edge := {
		"subject_node_id": subject,
		"predicate": predicate,
		"object_node_id": object_id,
		"confidence": 1.0,
		"visibility": "public",
		"source_type": "world_catalog",
		"source_id": source_id,
	}
	edges[_edge_key(edge)] = edge


func _edge_key(edge: Dictionary) -> String:
	return "%s|%s|%s|%s" % [
		String(edge.get("subject_node_id", "")),
		String(edge.get("predicate", "")),
		String(edge.get("object_node_id", "")),
		String(edge.get("source_id", "")),
	]


func _node_type(node_id: String) -> String:
	var prefix := node_id.get_slice(":", 0)
	if prefix in ["region", "location", "item", "quest", "concept", "building", "container", "crop"]:
		return prefix
	return "concept"


func _label_for_node(node_id: String) -> String:
	return node_id.get_slice(":", 1).replace("_", " ").capitalize()
