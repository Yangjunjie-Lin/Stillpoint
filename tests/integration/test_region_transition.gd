extends RefCounted


func run() -> bool:
	var town := ResourceRegistry.get_region(&"town")
	var wild := ResourceRegistry.get_region(&"wilderness")
	return town != null and wild != null and town.id != wild.id
