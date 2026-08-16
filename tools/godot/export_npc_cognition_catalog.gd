extends SceneTree

const OUTPUT_PATH := "res://services/npc_mind/catalog/generated_npc_catalog.json"
const PET_OUTPUT_PATH := "res://services/npc_mind/catalog/generated_pet_catalog.json"
const GAME_VERSION := "0.9.0"

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
	var pet_profiles := _build_pet_profiles(registry, errors)
	var world_ontology := _build_world_ontology(registry, errors)
	var hidden_encounter_ontology := _build_hidden_encounter_ontology(registry, errors)
	if not errors.is_empty():
		for message in errors:
			push_error("NPC catalog: %s" % message)
		quit(1)
		return
	var payload := {
		"catalog_version": 5,
		"game_version": GAME_VERSION,
		"npc_count": profiles.size(),
		"npcs": profiles,
		"world_ontology": world_ontology,
		"hidden_encounter_ontology": hidden_encounter_ontology,
		"relation_action_catalog": KnowledgeActionLibrary.catalog(),
	}
	var pet_payload := {
		"catalog_version": 2,
		"game_version": GAME_VERSION,
		"pet_count": pet_profiles.size(),
		"pets": pet_profiles,
	}
	var rendered := JSON.stringify(payload, "  ") + "\n"
	var pet_rendered := JSON.stringify(pet_payload, "  ") + "\n"
	var args := OS.get_cmdline_user_args()
	if "--check" in args:
		var catalogs_current := true
		catalogs_current = _check_catalog(OUTPUT_PATH, rendered, "NPC") \
			and catalogs_current
		catalogs_current = _check_catalog(PET_OUTPUT_PATH, pet_rendered, "Pet") \
			and catalogs_current
		if not catalogs_current:
			quit(1)
			return
		print("Cognition catalog validation: %d NPC profiles, %d pet profiles" % [
			profiles.size(), pet_profiles.size(),
		])
		quit(0)
		return
	if not _write_catalog(OUTPUT_PATH, rendered, "NPC"):
		quit(1)
		return
	if not _write_catalog(PET_OUTPUT_PATH, pet_rendered, "Pet"):
		quit(1)
		return
	print("Cognition catalogs exported: %d NPC profiles, %d pet profiles" % [
		profiles.size(), pet_profiles.size(),
	])
	quit(0)


func _check_catalog(path: String, rendered: String, label: String) -> bool:
	if not FileAccess.file_exists(path):
		push_error("%s catalog is missing: %s" % [label, path])
		return false
	if FileAccess.get_file_as_string(path) != rendered:
		push_error("%s catalog is stale; run export_npc_cognition_catalog.gd" % label)
		return false
	return true


func _write_catalog(path: String, rendered: String, label: String) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("Unable to write %s catalog" % label)
		return false
	file.store_string(rendered)
	file.close()
	return true


func _build_pet_profiles(registry: Node, errors: Array[String]) -> Array:
	var profiles: Array = []
	var profile_ids: Dictionary = {}
	for pet: Variant in registry.call("get_all_pet_companions"):
		var pet_id := String(pet.get("id"))
		if not bool(pet.call("is_valid")):
			errors.append("Pet '%s' has an invalid companion definition" % pet_id)
			continue
		var definition_id := String(pet.get("server_dialogue_profile_id"))
		if definition_id.is_empty():
			errors.append("Pet '%s' has no server_dialogue_profile_id" % pet_id)
			continue
		if profile_ids.has(definition_id):
			errors.append("Duplicate pet dialogue profile id '%s'" % definition_id)
			continue
		profile_ids[definition_id] = true
		profiles.append(_pet_profile_dict(pet, definition_id))
	profiles.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("definition_id", "")) < str(b.get("definition_id", "")))
	return profiles


func _pet_profile_dict(pet: Variant, definition_id: String) -> Dictionary:
	var display_name := String(pet.get("display_name"))
	var biography := String(pet.get("biography"))
	var species: Variant = pet.get("species")
	var personality: Variant = pet.get("personality")
	var species_id := String(species.get("id"))
	var species_name := String(species.get("display_name"))
	var species_description := String(species.get("description"))
	var life_skills: Array = pet.get("life_skills")
	var attack_skills: Array = pet.get("attack_skills")
	var lifestyles: Array = pet.get("lifestyles")
	var equipment_slots: Array = pet.get("equipment_slots")
	var knowledge_seeds: Array = [{
		"node_id": "concept:pet_bond",
		"node_type": "concept",
		"content": "Trust grows through feeding, care, play, rest, and shared experience.",
		"domain_tags": ["pet", "social"],
		"confidence": 1.0,
		"visibility": "public",
		"source_type": "authored",
		"source_id": definition_id,
	}]
	var cognitive_skills: Array = [{
		"id": "companion_social_cues",
		"display_name": "Companion Social Cues",
		"description": "Express mood, needs, affection, and uncertainty without directing gameplay.",
		"domain_tags": ["pet", "social"],
		"proficiency": float(personality.get("sociability")),
		"allowed_tool_ids": [],
		"knowledge_node_ids": ["concept:pet_bond"],
		"linked_gameplay_skill_ids": [],
		"response_constraints": [
			"Never claim a gameplay action happened unless a program-owned event says it happened.",
		],
	}]
	var linked_skill_ids: Array[String] = []
	var life_skill_ids: Array[String] = []
	var attack_skill_ids: Array[String] = []
	var life_skill_catalog: Array = []
	var attack_skill_catalog: Array = []
	for skill: Variant in life_skills:
		var skill_id := String(skill.get("id"))
		life_skill_ids.append(skill_id)
		linked_skill_ids.append(skill_id)
		life_skill_catalog.append(skill.call("to_catalog_dict"))
		knowledge_seeds.append(_pet_skill_knowledge_seed(skill, definition_id))
		cognitive_skills.append(_pet_cognitive_skill(skill))
	for skill: Variant in attack_skills:
		var skill_id := String(skill.get("id"))
		attack_skill_ids.append(skill_id)
		linked_skill_ids.append(skill_id)
		attack_skill_catalog.append(skill.call("to_catalog_dict"))
		knowledge_seeds.append(_pet_skill_knowledge_seed(skill, definition_id))
	var lifestyle_catalog: Array = []
	for lifestyle: Variant in lifestyles:
		lifestyle_catalog.append(lifestyle.call("to_catalog_dict"))
	var equipment_catalog: Array = []
	for slot: Variant in equipment_slots:
		equipment_catalog.append(slot.call("to_catalog_dict"))
	var biography_lines: Array[String] = []
	if not biography.is_empty():
		biography_lines.append(biography)
	if not species_description.is_empty():
		biography_lines.append(species_description)
	return {
		"definition_id": definition_id,
		"id": "%s_companion_mind" % String(pet.get("id")),
		"display_name": display_name,
		"identity": {
			"canonical_name": display_name,
			"aliases": [species_name],
			"species": species_id,
			"occupation": "companion",
			"social_role": "bonded_pet",
			"faction_ids": ["player_household"],
			"home_region_id": String(pet.get("default_stay_region_id")),
			"birth_region_id": "",
			"languages": ["common"],
			"public_description": species_description,
			"private_description": biography,
		},
		"personality": _pet_personality_dict(personality),
		"speech_style": {
			"formality": 0.1,
			"verbosity": 0.32,
			"sentence_length": "short",
			"preferred_terms": _strings(pet.get("speech_style_tags")),
			"forbidden_terms": ["system prompt", "database", "execute command"],
			"dialect_notes": "Warm, sensory, concise, and grounded in direct experience.",
			"greeting_patterns": [],
			"farewell_patterns": [],
			"emotional_expressions": [],
		},
		"biography": biography_lines,
		"values": ["bond", "safe_home", "curiosity", "play"],
		"taboos": ["abandon_owner", "invent_unwitnessed_facts"],
		"goals": [{
			"id": "stay_bonded",
			"description": "Remain connected to the owner while expressing needs honestly.",
			"priority": 10,
		}],
		"knowledge_seeds": knowledge_seeds,
		"belief_seeds": [],
		"relationship_seeds": [],
		"cognitive_skills": cognitive_skills,
		"linked_gameplay_skill_ids": linked_skill_ids,
		"pet_ontology": {
			"definition": pet.call("to_catalog_dict"),
			"species": {
				"id": species_id,
				"display_name": species_name,
				"catalog": species.call("to_catalog_dict"),
			},
			"base_attributes": pet.get("base_attributes").call("to_dict"),
			"lifestyles": lifestyle_catalog,
			"equipment_slots": equipment_catalog,
			"life_skills": life_skill_catalog,
			"attack_skills": attack_skill_catalog,
			"life_skill_ids": life_skill_ids,
			"attack_skill_ids": attack_skill_ids,
		},
		"memory_policy": {
			"recent_turn_limit": 8,
			"retrieval_limit": 10,
			"graph_depth": 2,
			"prompt_token_budget": 2400,
			"max_output_tokens": 320,
			"default_half_life_hours": 336.0,
			"high_salience_half_life_hours": 17520.0,
			"weights": {
				"semantic": 0.4,
				"salience": 0.16,
				"goal": 0.1,
				"graph": 0.1,
				"relationship": 0.12,
				"recency": 0.07,
				"reinforcement": 0.05,
			},
		},
		"response_constraints": [
			"The LLM may express personality, mood, observations, questions, and validated memory or graph candidates only.",
			"The LLM never controls movement, combat, equipment, feeding, skills, lifestyles, schedules, money, or canonical graph facts.",
			"Proactive dialogue is one program-requested line and does not authorize the model to schedule another turn.",
		],
		"system_prompt_addendum": "%s has a private first-person perspective and admits uncertainty about anything not authored, witnessed, sensed, remembered, or told by the player." % display_name,
	}


func _pet_personality_dict(personality: Variant) -> Dictionary:
	var curiosity := float(personality.get("curiosity"))
	var sociability := float(personality.get("sociability"))
	var loyalty := float(personality.get("loyalty"))
	var patience := float(personality.get("patience"))
	var playfulness := float(personality.get("playfulness"))
	var courage := float(personality.get("courage"))
	return {
		"openness": curiosity,
		"conscientiousness": clampf((loyalty + patience) * 0.5, 0.0, 1.0),
		"extraversion": sociability,
		"agreeableness": loyalty,
		"emotional_stability": patience,
		"curiosity": curiosity,
		"courage": courage,
		"empathy": loyalty,
		"greed": 0.0,
		"honesty": loyalty,
		"patience": patience,
		"humor": playfulness,
		"pet_temperament": personality.call("to_catalog_dict"),
	}


func _pet_skill_knowledge_seed(skill: Variant, definition_id: String) -> Dictionary:
	var skill_id := String(skill.get("id"))
	return {
		"node_id": "skill:%s" % skill_id,
		"node_type": "skill",
		"content": String(skill.get("description")),
		"domain_tags": _strings(skill.get("tags")),
		"confidence": 1.0,
		"visibility": "public",
		"source_type": "authored",
		"source_id": definition_id,
	}


func _pet_cognitive_skill(skill: Variant) -> Dictionary:
	var skill_id := String(skill.get("id"))
	return {
		"id": "%s_awareness" % skill_id,
		"display_name": "%s Awareness" % String(skill.get("display_name")),
		"description": "Talks only about direct or remembered experience with this authored life skill.",
		"domain_tags": _strings(skill.get("tags")),
		"proficiency": 0.5,
		"allowed_tool_ids": [],
		"knowledge_node_ids": ["skill:%s" % skill_id],
		"linked_gameplay_skill_ids": [skill_id],
		"response_constraints": [
			"Do not invent distant locations, unseen targets, rewards, or completed actions.",
		],
	}


func _strings(values: Variant) -> Array[String]:
	var result: Array[String] = []
	for value: Variant in values:
		result.append(String(value))
	return result


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
	for skill: Variant in registry.call("get_all_skills"):
		if not bool(skill.call("is_valid")):
			errors.append("Invalid gameplay skill definition '%s'" % String(skill.get("id")))
			continue
		var data := skill.call("to_catalog_dict") as Dictionary
		var skill_id := String(data.get("id", ""))
		var skill_node := String(data.get("node_id", "skill:%s" % skill_id))
		var category := String(data.get("category", "utility"))
		var domain_node := "concept:skill_domain_%s" % category
		var recovery_days := int(data.get("context_recovery_days", 2))
		var recovery_node := "concept:practice_recovery_%d_days" % recovery_days
		_add_world_node(nodes, skill_node, "skill", String(data.get("display_name", skill_id)), {
			"skill_id": skill_id,
			"category": category,
			"description": String(data.get("description", "")),
			"max_proficiency": float(data.get("max_proficiency", 100.0)),
			"daily_gain_cap": float(data.get("daily_gain_cap", 10.0)),
			"context_recovery_days": recovery_days,
			"overtraining_threshold": int(data.get("overtraining_threshold", 9)),
		})
		_add_world_node(nodes, domain_node, "concept", "%s Skill Domain" % category.capitalize(), {})
		_add_world_node(nodes, recovery_node, "concept", "%d Day Practice Recovery" % recovery_days, {})
		_add_world_edge(edges, skill_node, "BELONGS_TO", domain_node, skill_id)
		_add_world_edge(edges, skill_node, "RECOVERS_AFTER", recovery_node, skill_id)
		for tool_id_value: String in data.get("allowed_tool_ids", []):
			var tool: Variant = registry.call("get_item", StringName(tool_id_value))
			if tool == null:
				errors.append("Skill '%s' references unknown tool '%s'" % [skill_id, tool_id_value])
				continue
			var tool_node := "item:%s" % tool_id_value
			_add_world_node(nodes, tool_node, "item", String(tool.get("display_name")), {})
			_add_world_edge(edges, skill_node, "PRACTICED_WITH", tool_node, skill_id)
		for action_id: String in data.get("practice_action_ids", []):
			var action_node := "concept:practice_action_%s" % action_id
			_add_world_node(nodes, action_node, "concept", action_id.replace("_", " ").capitalize(), {})
			_add_world_edge(edges, skill_node, "PRACTICED_BY", action_node, skill_id)
		for related_id: String in data.get("related_skill_ids", []):
			var related: Variant = registry.call("get_skill", StringName(related_id))
			if related == null:
				errors.append("Skill '%s' references unknown related skill '%s'" % [skill_id, related_id])
				continue
			var related_node := String(related.call("resolved_ontology_node_id"))
			_add_world_node(nodes, related_node, "skill", String(related.get("display_name")), {})
			_add_world_edge(edges, skill_node, "SYNERGIZES_WITH", related_node, skill_id)
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
	for shop: Variant in registry.call("get_all_shops"):
		if not bool(shop.call("is_valid")):
			errors.append("Invalid shop definition '%s'" % String(shop.get("id")))
			continue
		var data := shop.call("to_catalog_dict") as Dictionary
		var shop_node := String(data.get("node_id", ""))
		var building_node := String(data.get("building_node_id", ""))
		var shopkeeper_id := String(data.get("shopkeeper_npc_definition_id", ""))
		var shopkeeper_node := "npc_definition:%s" % shopkeeper_id
		var building: Variant = registry.call("get_house", StringName(building_node))
		if building == null:
			errors.append("Shop '%s' references unknown building '%s'" % [shop_node, building_node])
			continue
		_add_world_node(
			nodes,
			shop_node,
			"shop",
			String(data.get("label", shop_node)),
			data.get("metadata", {}) as Dictionary,
		)
		_add_world_node(nodes, building_node, "building", String(building.get("display_name")), {})
		_add_world_edge(edges, shop_node, "LOCATED_IN", building_node, shop_node)
		if not shopkeeper_id.is_empty():
			var shopkeeper: Variant = registry.call("get_npc", StringName(shopkeeper_id))
			if shopkeeper == null:
				errors.append("Shop '%s' references unknown shopkeeper '%s'" % [shop_node, shopkeeper_id])
			else:
				_add_world_node(
					nodes,
					shopkeeper_node,
					"npc_definition",
					String(shopkeeper.get("display_name")),
					{"definition_id": shopkeeper_id},
				)
				_add_world_edge(edges, shop_node, "OPERATED_BY", shopkeeper_node, shop_node)
		for offer_data: Dictionary in data.get("offers", []):
			var offer_node := String(offer_data.get("node_id", ""))
			var item_node := String(offer_data.get("item_node_id", ""))
			var offer_metadata := offer_data.get("metadata", {}) as Dictionary
			var item_id := String(offer_metadata.get("item_id", ""))
			var item: Variant = registry.call("get_item", StringName(item_id))
			if item == null:
				errors.append("Shop '%s' offer '%s' references unknown item '%s'" % [
					shop_node, offer_node, item_id,
				])
				continue
			_add_world_node(
				nodes,
				offer_node,
				"shop_offer",
				String(item.get("display_name")),
				offer_metadata,
			)
			_add_world_node(nodes, item_node, "item", String(item.get("display_name")), {})
			_add_world_edge(edges, shop_node, "OFFERS", offer_node, shop_node)
			_add_world_edge(edges, offer_node, "SELLS", item_node, shop_node)
			_add_world_edge(edges, shop_node, "SELLS", item_node, shop_node)
	for recipe: Variant in registry.call("get_all_forge_recipes"):
		if not bool(recipe.call("is_valid")):
			errors.append("Invalid forge recipe '%s'" % String(recipe.get("id")))
			continue
		var data := recipe.call("to_catalog_dict") as Dictionary
		var recipe_node := String(data.get("node_id", ""))
		var building_node := String(data.get("building_node_id", ""))
		var smith_id := String(data.get("smith_npc_definition_id", ""))
		var smith_node := "npc_definition:%s" % smith_id
		var building: Variant = registry.call("get_house", StringName(building_node))
		var smith: Variant = registry.call("get_npc", StringName(smith_id))
		if building == null:
			errors.append("Forge recipe '%s' references unknown building '%s'" % [recipe_node, building_node])
			continue
		if smith == null:
			errors.append("Forge recipe '%s' references unknown smith '%s'" % [recipe_node, smith_id])
			continue
		var recipe_metadata := (data.get("metadata", {}) as Dictionary).duplicate(true)
		recipe_metadata["input_items"] = data.get("input_items", [])
		recipe_metadata["output_item_node_id"] = data.get("output_item_node_id", "")
		_add_world_node(
			nodes,
			recipe_node,
			"forge_recipe",
			String(data.get("label", recipe_node)),
			recipe_metadata,
		)
		_add_world_node(nodes, building_node, "building", String(building.get("display_name")), {})
		_add_world_node(
			nodes,
			smith_node,
			"npc_definition",
			String(smith.get("display_name")),
			{"definition_id": smith_id},
		)
		_add_world_edge(edges, recipe_node, "AVAILABLE_AT", building_node, recipe_node)
		_add_world_edge(edges, recipe_node, "PERFORMED_BY", smith_node, recipe_node)
		for input_data: Dictionary in data.get("input_items", []):
			var item_node := String(input_data.get("item_node_id", ""))
			var item_id := item_node.trim_prefix("item:")
			var item: Variant = registry.call("get_item", StringName(item_id))
			if item == null:
				errors.append("Forge recipe '%s' references unknown material '%s'" % [
					recipe_node, item_id,
				])
				continue
			_add_world_node(nodes, item_node, "item", String(item.get("display_name")), {})
			_add_world_edge(edges, recipe_node, "REQUIRES_MATERIAL", item_node, recipe_node)
		var output_item_node := String(data.get("output_item_node_id", ""))
		var output_item_id := output_item_node.trim_prefix("item:")
		var output_item: Variant = registry.call("get_item", StringName(output_item_id))
		if output_item == null:
			errors.append("Forge recipe '%s' references unknown output '%s'" % [
				recipe_node, output_item_id,
			])
		else:
			_add_world_node(
				nodes,
				output_item_node,
				"item",
				String(output_item.get("display_name")),
				{},
			)
			_add_world_edge(edges, recipe_node, "PRODUCES", output_item_node, recipe_node)
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


func _build_hidden_encounter_ontology(registry: Node, errors: Array[String]) -> Dictionary:
	## Never merge this catalog into `world_ontology`: it contains undiscovered
	## trigger/reward structure and is for trusted server/runtime validation only.
	var encounters: Array[Dictionary] = []
	var public_nodes: Array[Dictionary] = []
	var public_edges: Array[Dictionary] = []
	for encounter: Variant in registry.call("get_all_encounters"):
		if not bool(encounter.call("is_valid")):
			errors.append("Invalid hidden encounter '%s'" % String(encounter.get("id")))
			continue
		var data := encounter.call("public_catalog_dict") as Dictionary
		var encounter_id := String(data.get("id", ""))
		var encounter_node := String(data.get("node_id", "encounter:%s" % encounter_id))
		encounters.append({
			"id": encounter_id,
			"node_id": encounter_node,
			"trigger_kind": data.get("trigger_kind", ""),
			"repeat_policy": data.get("repeat_policy", ""),
			"visibility_policy": data.get("visibility_policy", ""),
			"condition_count": (encounter.get("conditions") as Array).size(),
			"reward_effect_count": (encounter.get("reward_effects") as Array).size(),
		})
		public_nodes.append({
			"node_id": encounter_node,
			"node_type": "encounter",
			"label": String(data.get("display_name", encounter_id)),
			"metadata": {
				"lore_tags": data.get("lore_tags", []),
			},
		})
		for participant_id: String in data.get("participant_node_ids", []):
			public_edges.append(_hidden_public_edge(encounter_node, "INVOLVES", participant_id))
		var location_id := String(data.get("public_location_node_id", ""))
		if not location_id.is_empty():
			public_edges.append(_hidden_public_edge(encounter_node, "DISCOVERED_IN", location_id))
		for category_id: String in data.get("public_reward_category_ids", []):
			public_edges.append(_hidden_public_edge(encounter_node, "MAY_REWARD", category_id))
	encounters.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("id", "")) < str(b.get("id", "")))
	public_nodes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("node_id", "")) < str(b.get("node_id", "")))
	public_edges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return _edge_key(a) < _edge_key(b))
	return {
		"schema_version": 1,
		"visibility": "server_hidden_until_discovery",
		"encounters": encounters,
		"discovered_public_nodes": public_nodes,
		"discovered_public_edges": public_edges,
	}


func _hidden_public_edge(subject: String, predicate: String, object_id: String) -> Dictionary:
	return {
		"subject_node_id": subject,
		"predicate": predicate,
		"object_node_id": object_id,
	}


func _add_world_node(
	nodes: Dictionary,
	node_id: String,
	node_type: String,
	label: String,
	metadata: Dictionary,
) -> void:
	if node_id.is_empty():
		return
	if nodes.has(node_id):
		var existing: Dictionary = nodes[node_id]
		var merged_metadata: Dictionary = existing.get("metadata", {}).duplicate(true)
		merged_metadata.merge(metadata, true)
		existing["metadata"] = merged_metadata
		if not label.is_empty():
			existing["label"] = label
		if not node_type.is_empty():
			existing["node_type"] = node_type
		nodes[node_id] = existing
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
	if prefix == "forge":
		return "forge_recipe"
	if prefix in [
		"region", "location", "item", "quest", "concept", "building", "container",
		"crop", "shop", "shop_offer",
	]:
		return prefix
	return "concept"


func _label_for_node(node_id: String) -> String:
	return node_id.get_slice(":", 1).replace("_", " ").capitalize()
