class_name PetAttributeProfile
extends Resource
## Immutable authored attributes for a pet species/individual definition.
## Runtime changes are copied into PetRuntimeState and never written back here.

const MIN_ATTRIBUTE := 1
const MAX_ATTRIBUTE := 100

@export_range(MIN_ATTRIBUTE, MAX_ATTRIBUTE, 1) var strength: int = 5
@export_range(MIN_ATTRIBUTE, MAX_ATTRIBUTE, 1) var vitality: int = 5
@export_range(MIN_ATTRIBUTE, MAX_ATTRIBUTE, 1) var agility: int = 5
@export_range(MIN_ATTRIBUTE, MAX_ATTRIBUTE, 1) var endurance: int = 5
@export_range(MIN_ATTRIBUTE, MAX_ATTRIBUTE, 1) var focus: int = 5
@export_range(MIN_ATTRIBUTE, MAX_ATTRIBUTE, 1) var perception: int = 5
@export_range(MIN_ATTRIBUTE, MAX_ATTRIBUTE, 1) var sociability: int = 5


func is_valid() -> bool:
	for value in to_dict().values():
		if int(value) < MIN_ATTRIBUTE or int(value) > MAX_ATTRIBUTE:
			return false
	return true


func to_dict() -> Dictionary:
	return {
		"strength": strength,
		"vitality": vitality,
		"agility": agility,
		"endurance": endurance,
		"focus": focus,
		"perception": perception,
		"sociability": sociability,
	}


func value_for(attribute_id: StringName) -> int:
	return int(to_dict().get(String(attribute_id), 0))
