extends RefCounted


func run() -> bool:
	var bandits := ResourceRegistry.get_faction(&"bandits")
	var town := ResourceRegistry.get_faction(&"townfolk")
	return bandits != null and town != null and bandits.enemies.has(&"townfolk")
