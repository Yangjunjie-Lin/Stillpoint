class_name PetPersonalityProfile
extends Resource
## Authored, auditable temperament. It supplies deterministic behavior biases
## and prompt context; an LLM cannot replace these server-owned values.

@export var id: StringName = &"balanced"
@export var display_name: String = "Balanced"
@export_range(0.0, 1.0, 0.01) var courage: float = 0.5
@export_range(0.0, 1.0, 0.01) var curiosity: float = 0.5
@export_range(0.0, 1.0, 0.01) var sociability: float = 0.5
@export_range(0.0, 1.0, 0.01) var independence: float = 0.5
@export_range(0.0, 1.0, 0.01) var loyalty: float = 0.5
@export_range(0.0, 1.0, 0.01) var playfulness: float = 0.5
@export_range(0.0, 1.0, 0.01) var aggression: float = 0.25
@export_range(0.0, 1.0, 0.01) var patience: float = 0.5
@export_range(0.0, 100.0, 0.5) var initial_mood: float = 70.0
@export_range(0.0, 100.0, 0.5) var hunger_discomfort_threshold: float = 65.0


func is_valid() -> bool:
	if id == &"" or display_name.strip_edges().is_empty():
		return false
	for value in [
		courage, curiosity, sociability, independence, loyalty,
		playfulness, aggression, patience,
	]:
		if value < 0.0 or value > 1.0:
			return false
	return initial_mood >= 0.0 and initial_mood <= 100.0 \
		and hunger_discomfort_threshold >= 0.0 \
		and hunger_discomfort_threshold <= 100.0


func behavior_biases() -> Dictionary:
	return {
		"approach_owner": clampf(loyalty * 0.55 + sociability * 0.45, 0.0, 1.0),
		"explore": clampf(curiosity * 0.7 + independence * 0.3, 0.0, 1.0),
		"initiate_social": clampf(sociability * 0.65 + playfulness * 0.35, 0.0, 1.0),
		"engage_hostile": clampf(courage * 0.55 + aggression * 0.45, 0.0, 1.0),
		"retreat": clampf(1.0 - courage * 0.8 - aggression * 0.2, 0.0, 1.0),
		"wait_calmly": clampf(patience * 0.75 + loyalty * 0.25, 0.0, 1.0),
	}


func to_catalog_dict() -> Dictionary:
	var result := behavior_biases()
	result.merge({
		"id": String(id),
		"display_name": display_name,
		"courage": courage,
		"curiosity": curiosity,
		"sociability": sociability,
		"independence": independence,
		"loyalty": loyalty,
		"playfulness": playfulness,
		"aggression": aggression,
		"patience": patience,
	})
	return result
