class_name DialogueSelectorDefinition
extends Resource

@export var entries: Array[DialogueSelectorEntry] = []


func select(context: WorldSessionContext) -> DialogueDefinition:
	for entry in entries:
		if entry == null:
			continue
		if entry.conditions.is_empty():
			return entry.dialogue
		var all_ok := true
		for cond in entry.conditions:
			if cond != null and not cond.evaluate(context):
				all_ok = false
				break
		if all_ok and entry.dialogue != null:
			return entry.dialogue
	return null
