class_name NPCIdentityDefinition
extends Resource

## Authoritative, authored identity data for an NPC.  This resource is never
## populated from model output; it is part of the shipped content catalog.
@export var canonical_name: String = ""
@export var aliases: Array[String] = []
@export var species: StringName = &"human"
@export var age_group: StringName = &"adult"
@export var gender_identity: StringName = &"unspecified"
@export var occupation: StringName = &""
@export var social_role: StringName = &""
@export var faction_ids: Array[StringName] = []
@export var home_region_id: StringName = &""
@export var birth_region_id: StringName = &""
@export var languages: Array[StringName] = [&"common"]
@export var cultural_background: StringName = &""
@export_multiline var public_description: String = ""
@export_multiline var private_description: String = ""

func to_catalog_dict() -> Dictionary:
	return {
		"canonical_name": canonical_name,
		"aliases": aliases.duplicate(),
		"species": String(species),
		"age_group": String(age_group),
		"gender_identity": String(gender_identity),
		"occupation": String(occupation),
		"social_role": String(social_role),
		"faction_ids": _strings(faction_ids),
		"home_region_id": String(home_region_id),
		"birth_region_id": String(birth_region_id),
		"languages": _strings(languages),
		"cultural_background": String(cultural_background),
		"public_description": public_description,
		"private_description": private_description,
	}

func _strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result
