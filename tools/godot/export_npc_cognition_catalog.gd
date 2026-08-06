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
	if not errors.is_empty():
		for message in errors:
			push_error("NPC catalog: %s" % message)
		quit(1)
		return
	var payload := {
		"catalog_version": 1,
		"game_version": "0.8.0",
		"npc_count": profiles.size(),
		"npcs": profiles,
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
