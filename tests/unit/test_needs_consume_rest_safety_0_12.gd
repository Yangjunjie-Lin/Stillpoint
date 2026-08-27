extends RefCounted


func run() -> bool:
	var needs := NeedsComponent.new()
	needs.last_updated_world_hour = 32
	needs.food_need = 0.2
	needs.rest_need = 0.2
	needs.advance_to(1, 12, &"work")
	var ok: bool = needs.food_need > 0.2 and needs.rest_need > 0.2
	var deterministic := NeedsComponent.new()
	deterministic.last_updated_world_hour = 32
	deterministic.food_need = 0.2
	deterministic.rest_need = 0.2
	deterministic.advance_to(1, 12, &"work")
	ok = ok and needs.to_dict() == deterministic.to_dict()
	var energy := EnergyComponent.new()
	energy.max_energy = 100.0
	energy.current_energy = 25.0
	var rest_before := needs.rest_need
	needs.rest(2.0, energy)
	ok = ok and needs.rest_need < rest_before and energy.current_energy > 25.0
	needs.react_to_aggression(0.8)
	ok = ok and needs.is_safety_critical()
	var saved := needs.to_dict()
	var restored := NeedsComponent.new()
	ok = restored.from_dict(saved) and ok
	ok = ok and restored.to_dict() == saved
	needs.free()
	deterministic.free()
	energy.free()
	restored.free()

	var actor := EconomicTestHelper.make_blacksmith_actor(&"npc:consume", 20)
	actor.needs.food_need = 0.9
	actor.inventory.add_item(&"trail_snack", 1)
	var slot := _find(actor.inventory, &"trail_snack")
	var economy := ActorEconomyService.new()
	economy.setup(null, null)
	var intent := ConsumeIntent.new(actor.get_persistent_actor_id(), slot, &"trail_snack", 1, 1)
	var before_need := actor.needs.food_need
	var consumed := economy.execute_consume(actor, intent, &"consume-test")
	ok = ok and bool(consumed.get("success", false))
	ok = ok and actor.inventory.count_item(&"trail_snack") == 0
	ok = ok and actor.needs.food_need < before_need
	ok = ok and actor.employment.economic_sequence == 1
	actor.free()
	economy.free()
	if not ok:
		push_error("deterministic needs, rest, safety, persistence, or food sink failed")
	return ok


func _find(inventory: InventoryComponent, item_id: StringName) -> int:
	for index in inventory.slot_count:
		var stack := inventory.get_slot(index)
		if stack != null and stack.item_id == item_id:
			return index
	return -1
