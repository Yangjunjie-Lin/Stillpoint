class_name NPCSpeechStyleDefinition
extends Resource

@export_range(0.0, 1.0) var formality: float = 0.5
@export_range(0.0, 1.0) var verbosity: float = 0.5
@export var sentence_length: StringName = &"medium"
@export var preferred_terms: Array[String] = []
@export var forbidden_terms: Array[String] = []
@export_multiline var dialect_notes: String = ""
@export var greeting_patterns: Array[String] = []
@export var farewell_patterns: Array[String] = []
@export var emotional_expressions: Array[String] = []

func to_catalog_dict() -> Dictionary:
	return {
		"formality": clampf(formality, 0.0, 1.0),
		"verbosity": clampf(verbosity, 0.0, 1.0),
		"sentence_length": String(sentence_length),
		"preferred_terms": preferred_terms.duplicate(),
		"forbidden_terms": forbidden_terms.duplicate(),
		"dialect_notes": dialect_notes,
		"greeting_patterns": greeting_patterns.duplicate(),
		"farewell_patterns": farewell_patterns.duplicate(),
		"emotional_expressions": emotional_expressions.duplicate(),
	}
