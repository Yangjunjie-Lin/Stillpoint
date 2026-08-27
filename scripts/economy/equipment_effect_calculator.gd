class_name EquipmentEffectCalculator
extends RefCounted
## Shared authored equipment aggregation for every actor type.


static func calculate(equipment: EquipmentComponent) -> Dictionary:
	var result := {
		"attack_bonus": 0.0,
		"defense_bonus": 0.0,
		"energy_regen_bonus": 0.0,
		"max_health_bonus": 0.0,
		"max_energy_bonus": 0.0,
		"move_speed_bonus": 0.0,
	}
	if equipment == null:
		return result
	for slot in EquipmentComponent.EQUIP_SLOTS:
		var item := equipment.get_equipped_definition(slot)
		if item == null or item.is_decorative_equipment():
			continue
		result["attack_bonus"] += item.attack_bonus
		result["defense_bonus"] += item.defense_bonus
		result["energy_regen_bonus"] += item.energy_regen_bonus
		result["max_health_bonus"] += item.max_health_bonus
		result["max_energy_bonus"] += item.max_energy_bonus
		result["move_speed_bonus"] += item.move_speed_bonus
	return result


static func best_work_tool(equipment: EquipmentComponent, required_tags: Array[StringName]) -> ItemDefinition:
	var best: ItemDefinition = null
	if equipment == null:
		return best
	for slot in EquipmentComponent.EQUIP_SLOTS:
		var item := equipment.get_equipped_definition(slot)
		if item == null or not item.supports_all_work_tags(required_tags):
			continue
		if best == null or item.work_efficiency > best.work_efficiency:
			best = item
	return best
