class_name PetCompanionDefinition
extends Resource
## Canonical definition for an individual adoptable pet archetype. Runtime
## ownership, condition, progression, and equipment are intentionally absent.

@export var id: StringName = &"pet"
@export var display_name: String = "Pet"
@export_multiline var biography: String = ""
@export var scene: PackedScene
@export var species: PetSpeciesDefinition
@export var personality: PetPersonalityProfile
@export var base_attributes: PetAttributeProfile
@export var lifestyles: Array[PetLifestyleDefinition] = []
@export var default_lifestyle_id: StringName = &""
@export var life_skills: Array[PetSkillDefinition] = []
@export var attack_skills: Array[PetSkillDefinition] = []
@export var equipment_slots: Array[PetEquipmentSlotDefinition] = []
@export var server_dialogue_profile_id: StringName = &""
@export var speech_style_tags: Array[StringName] = []
@export var llm_advisory_intent_ids: Array[StringName] = []
@export var default_stay_region_id: StringName = &"base:player_home"
@export var default_stay_location_id: StringName = &"pet_rest_area"


func is_valid() -> bool:
	if (
		id == &""
		or display_name.strip_edges().is_empty()
		or species == null
		or not species.is_valid()
		or personality == null
		or not personality.is_valid()
		or base_attributes == null
		or not base_attributes.is_valid()
	):
		return false
	if not lifestyles.is_empty() and get_lifestyle(default_lifestyle_id) == null:
		return false
	var seen: Dictionary = {}
	for lifestyle in lifestyles:
		if lifestyle == null or not lifestyle.is_valid() \
				or not _claim_unique(seen, "lifestyle:%s" % String(lifestyle.id)):
			return false
	for skill in life_skills:
		if skill == null or not skill.is_valid() or skill.is_attack_skill() \
				or not _claim_unique(seen, "skill:%s" % String(skill.id)):
			return false
	for skill in attack_skills:
		if skill == null or not skill.is_valid() or not skill.is_attack_skill() \
				or not _claim_unique(seen, "skill:%s" % String(skill.id)):
			return false
	for slot in equipment_slots:
		if slot == null or not slot.is_valid() \
				or not _claim_unique(seen, "slot:%s" % String(slot.id)):
			return false
	return true


func get_lifestyle(lifestyle_id: StringName) -> PetLifestyleDefinition:
	for lifestyle in lifestyles:
		if lifestyle != null and lifestyle.id == lifestyle_id:
			return lifestyle
	return null


func get_skill(skill_id: StringName) -> PetSkillDefinition:
	for skill in life_skills:
		if skill != null and skill.id == skill_id:
			return skill
	for skill in attack_skills:
		if skill != null and skill.id == skill_id:
			return skill
	return null


func get_equipment_slot(slot_id: StringName) -> PetEquipmentSlotDefinition:
	for slot in equipment_slots:
		if slot != null and slot.id == slot_id:
			return slot
	return null


func supports_advisory_intent(intent_id: StringName) -> bool:
	return intent_id != &"" and llm_advisory_intent_ids.has(intent_id)


func ontology_node_id() -> StringName:
	var raw := String(id)
	return id if raw.begins_with("pet:") else StringName("pet:%s" % raw)


func to_catalog_dict() -> Dictionary:
	return {
		"node_id": String(ontology_node_id()),
		"node_type": "pet",
		"label": display_name,
		"metadata": {
			"definition_id": String(id),
			"biography": biography,
			"species_id": String(species.id) if species != null else "",
			"personality_id": String(personality.id) if personality != null else "",
			"default_lifestyle_id": String(default_lifestyle_id),
			"life_skill_ids": _resource_ids(life_skills),
			"attack_skill_ids": _resource_ids(attack_skills),
			"equipment_slot_ids": _resource_ids(equipment_slots),
			"server_dialogue_profile_id": String(server_dialogue_profile_id),
		},
	}


func _claim_unique(seen: Dictionary, key: String) -> bool:
	if seen.has(key):
		return false
	seen[key] = true
	return true


func _resource_ids(resources: Array) -> Array[String]:
	var result: Array[String] = []
	for resource in resources:
		if resource != null:
			result.append(String(resource.get("id")))
	return result
