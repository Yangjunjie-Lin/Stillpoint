class_name PetLifestyleDefinition
extends Resource
## A player-selectable routine used when a pet is not following. The behavior
## controller may choose only authored program action IDs from this resource.

@export var id: StringName = &"home_companion"
@export var display_name: String = "Home Companion"
@export_multiline var description: String = ""
@export var preferred_location_tags: Array[StringName] = []
@export var permitted_program_action_ids: Array[StringName] = []
@export var practiced_life_skill_ids: Array[StringName] = []
@export_range(0.0, 4.0, 0.05) var activity_multiplier: float = 1.0
@export_range(0.0, 4.0, 0.05) var rest_multiplier: float = 1.0
@export_range(0.0, 4.0, 0.05) var hunger_multiplier: float = 1.0
@export var permits_independent_combat: bool = false


func is_valid() -> bool:
	return (
		id != &""
		and not display_name.strip_edges().is_empty()
		and activity_multiplier >= 0.0
		and rest_multiplier >= 0.0
		and hunger_multiplier >= 0.0
	)


func to_catalog_dict() -> Dictionary:
	return {
		"id": String(id),
		"display_name": display_name,
		"description": description,
		"preferred_location_tags": _strings(preferred_location_tags),
		"permitted_program_action_ids": _strings(permitted_program_action_ids),
		"practiced_life_skill_ids": _strings(practiced_life_skill_ids),
		"permits_independent_combat": permits_independent_combat,
	}


func permits_action(action_id: StringName) -> bool:
	return action_id != &"" and permitted_program_action_ids.has(action_id)


func _strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result
