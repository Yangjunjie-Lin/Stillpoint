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
		"catalog_version": 2,
		"game_version": "0.8.0",
		"npc_count": profiles.size(),
		"npcs": profiles,
		"world_ontology": world_ontology,
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
		})
		for target: StringName in region.get("connected_region_ids"):
			_add_world_edge(edges, node_id, "CONNECTED_TO", "region:%s" % String(target), region_id)
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
	if prefix in ["region", "location", "item", "quest", "concept", "building"]:
		return prefix
	return "concept"


func _label_for_node(node_id: String) -> String:
	return node_id.get_slice(":", 1).replace("_", " ").capitalize()
