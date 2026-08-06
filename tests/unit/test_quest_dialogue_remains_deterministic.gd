extends RefCounted

func run() -> bool:
	var definition := ResourceRegistry.get_npc(&"mira")
	return definition != null and definition.default_dialogue != null
