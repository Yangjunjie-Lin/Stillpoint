extends RefCounted


func run() -> bool:
	var expected_ids: Array[StringName] = [&"mossfox", &"stonehound", &"cloudowl"]
	var profiles: Dictionary = {}
	var species: Dictionary = {}
	var personalities: Dictionary = {}
	var attribute_signatures: Dictionary = {}
	var life_skills: Dictionary = {}
	var attack_skills: Dictionary = {}
	var all_definitions := ResourceRegistry.get_all_pet_companions()
	var ok := all_definitions.size() >= expected_ids.size()

	for definition_id in expected_ids:
		var definition := ResourceRegistry.get_pet_companion(definition_id)
		if definition == null or not definition.is_valid():
			push_error("missing or invalid pet companion definition: %s" % definition_id)
			ok = false
			continue
		ok = ok and definition.scene != null and definition.scene.can_instantiate()
		profiles[String(definition.server_dialogue_profile_id)] = true
		species[String(definition.species.id)] = true
		personalities[String(definition.personality.id)] = true
		attribute_signatures[_attribute_signature(definition.base_attributes)] = true
		ok = ok and definition.get_lifestyle(definition.default_lifestyle_id) != null
		ok = ok and not definition.life_skills.is_empty()
		ok = ok and not definition.attack_skills.is_empty()
		for slot: PetEquipmentSlotDefinition in definition.equipment_slots:
			ok = ok and _has_catalog_item_for_slot(definition, slot)
		for skill in definition.life_skills:
			life_skills[String(skill.id)] = true
		for skill in definition.attack_skills:
			attack_skills[String(skill.id)] = true

	ok = ok and profiles.size() == expected_ids.size()
	ok = ok and species.size() == expected_ids.size()
	ok = ok and personalities.size() == expected_ids.size()
	ok = ok and attribute_signatures.size() == expected_ids.size()
	ok = ok and life_skills.size() >= expected_ids.size()
	ok = ok and attack_skills.size() == expected_ids.size()

	var stonehound := ResourceRegistry.get_pet_companion(&"stonehound")
	var cloudowl := ResourceRegistry.get_pet_companion(&"cloudowl")
	if stonehound != null and cloudowl != null:
		ok = ok and stonehound.base_attributes.strength > cloudowl.base_attributes.strength
		ok = ok and cloudowl.base_attributes.agility > stonehound.base_attributes.agility
		ok = ok and cloudowl.base_attributes.perception > stonehound.base_attributes.perception
		ok = ok and stonehound.scene != null and cloudowl.scene != null
	if not ok:
		push_error("authored pet types are not independently registered or differentiated")
	return ok


func _attribute_signature(attributes: PetAttributeProfile) -> String:
	return "%d:%d:%d:%d:%d:%d:%d" % [
		attributes.strength,
		attributes.vitality,
		attributes.agility,
		attributes.endurance,
		attributes.focus,
		attributes.perception,
		attributes.sociability,
	]


func _has_catalog_item_for_slot(
	definition: PetCompanionDefinition,
	slot: PetEquipmentSlotDefinition,
) -> bool:
	for item: ItemDefinition in ResourceRegistry.get_all_items():
		if item.is_pet_equipment() and slot.accepts(
			item.pet_tags,
			item.equipment_weight,
			definition.species.species_tags,
		):
			return true
	return false
