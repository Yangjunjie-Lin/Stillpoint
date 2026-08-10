extends RefCounted


func run() -> bool:
	var fresh := FactionDefinition.new()
	if fresh.selectable or not fresh.description.is_empty() or fresh.signature_stat != &"":
		push_error("New faction build fields are not backward-compatible")
		return false

	var legacy := ResourceRegistry.get_faction(&"bandits")
	if legacy == null or legacy.selectable or legacy.signature_stat != &"":
		push_error("Legacy faction resources must remain non-selectable and neutral")
		return false
	return legacy.enemies.has(&"townfolk")
