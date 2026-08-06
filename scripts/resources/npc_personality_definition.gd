class_name NPCPersonalityDefinition
extends Resource

## Normalized personality dimensions.  Keeping these as fields makes behavior
## auditable and allows deterministic prompt assembly and testing.
@export_range(0.0, 1.0) var openness: float = 0.5
@export_range(0.0, 1.0) var conscientiousness: float = 0.5
@export_range(0.0, 1.0) var extraversion: float = 0.5
@export_range(0.0, 1.0) var agreeableness: float = 0.5
@export_range(0.0, 1.0) var emotional_stability: float = 0.5
@export_range(0.0, 1.0) var curiosity: float = 0.5
@export_range(0.0, 1.0) var courage: float = 0.5
@export_range(0.0, 1.0) var empathy: float = 0.5
@export_range(0.0, 1.0) var greed: float = 0.5
@export_range(0.0, 1.0) var honesty: float = 0.5
@export_range(0.0, 1.0) var patience: float = 0.5
@export_range(0.0, 1.0) var humor: float = 0.5

func to_catalog_dict() -> Dictionary:
	var result := {}
	for property in [
		"openness", "conscientiousness", "extraversion", "agreeableness",
		"emotional_stability", "curiosity", "courage", "empathy", "greed",
		"honesty", "patience", "humor",
	]:
		result[property] = clampf(float(get(property)), 0.0, 1.0)
	return result
