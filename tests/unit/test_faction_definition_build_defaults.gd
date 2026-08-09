extends RefCounted


func run() -> bool:
	var fresh := FactionDefinition.new()
	if fresh.selectable or not fresh.description.is_empty():
		push_error("New faction presentation fields are not backward-compatible")
		return false
	if not _bonuses_are_zero(fresh):
		push_error("New faction stat bonuses must default to zero")
		return false

	var legacy := ResourceRegistry.get_faction(&"bandits")
	if legacy == null or legacy.selectable or not _bonuses_are_zero(legacy):
		push_error("Legacy faction resources must remain non-selectable and neutral")
		return false
	return legacy.enemies.has(&"townfolk")


func _bonuses_are_zero(faction: FactionDefinition) -> bool:
	return (
		is_zero_approx(faction.max_health_bonus)
		and is_zero_approx(faction.max_energy_bonus)
		and is_zero_approx(faction.attack_bonus)
		and is_zero_approx(faction.defense_bonus)
		and is_zero_approx(faction.move_speed_bonus)
		and is_zero_approx(faction.energy_regen_bonus)
	)
