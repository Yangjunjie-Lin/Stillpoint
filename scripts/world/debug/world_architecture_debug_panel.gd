extends CanvasLayer
## World architecture debug panel (disabled in release by default).

@onready var label: Label = $Panel/Label

var _session: WorldSession


func _ready() -> void:
	visible = OS.is_debug_build()
	_session = _find_session()


func _process(_delta: float) -> void:
	if not visible or _session == null or label == null:
		return
	var lines: PackedStringArray = []
	lines.append("Current Region: %s" % String(_session.current_region_id))
	lines.append("Loaded Entities: %d" % _session.entity_repository.get_loaded_count())
	lines.append("Snapshots: %d" % _session.entity_repository.get_snapshot_count())
	lines.append("Interactables: %d" % _session.interaction_index.get_registered_count())
	var tracked := QuestManager.get_tracked_quest()
	lines.append("Tracked Quest: %s" % (String(tracked.quest_id) if tracked else "-"))
	lines.append("Active Quests: %d" % QuestManager.get_active_quests().size())
	lines.append("Last Save: %s" % _session.save_coordinator.get_last_save_result())
	var npc := _selected_npc()
	if npc != null:
		lines.append("--- Economic Actor ---")
		lines.append("Persistent ID: %s" % String(npc.get_persistent_actor_id()))
		lines.append("Wallet: %d" % (npc.wallet.get_balance() if npc.wallet != null else 0))
		lines.append("Energy: %.1f / %.1f" % [
			npc.energy.current_energy if npc.energy != null else 0.0,
			npc.energy.max_energy if npc.energy != null else 0.0,
		])
		var contract := npc.employment.current_contract if npc.employment != null else null
		lines.append("Job: %s" % (String(contract.job_id) if contract != null else "-"))
		lines.append("Worksite: %s" % (String(contract.worksite_id) if contract != null else "-"))
		var worksite_state := _session.actor_economy_service.get_worksite_state(contract.worksite_id) \
			if contract != null and _session.actor_economy_service != null else null
		lines.append("Payroll: %d" % (worksite_state.payroll_balance if worksite_state != null else 0))
		lines.append("NPC State: %s" % NPCController.NPCState.keys()[npc.npc_state])
		lines.append("Smithing: %.1f" % (npc.skills.get_points(&"smithing") if npc.skills != null else 0.0))
		lines.append("Inventory: %s" % _inventory_summary(npc.inventory))
		var smithing_tags: Array[StringName] = [&"smithing"]
		var tool := EquipmentEffectCalculator.best_work_tool(npc.equipment, smithing_tags)
		lines.append("Work Tool: %s" % (tool.display_name if tool != null else "-"))
		if npc.employment != null:
			lines.append("Economic Sequence: %d" % npc.employment.economic_sequence)
			lines.append("Last Work: %s" % JSON.stringify(npc.employment.last_work_result))
	label.text = "\n".join(lines)


func _find_session() -> WorldSession:
	var node := get_parent()
	if node is WorldSession:
		return node as WorldSession
	return null


func _selected_npc() -> NPCController:
	if _session == null or _session.player == null:
		return null
	if _session.player.targeting != null and _session.player.targeting.locked_target is NPCController:
		return _session.player.targeting.locked_target as NPCController
	var best: NPCController = null
	var best_distance := INF
	for entity in _session.entity_repository.get_loaded_entities_in_region(_session.current_region_id):
		if not entity is NPCController:
			continue
		var distance := _session.player.global_position.distance_to((entity as NPCController).global_position)
		if distance < best_distance:
			best_distance = distance
			best = entity as NPCController
	return best


func _inventory_summary(inventory: InventoryComponent) -> String:
	if inventory == null:
		return "-"
	var parts: Array[String] = []
	for index in inventory.slot_count:
		var stack := inventory.get_slot(index)
		if stack == null or stack.is_empty():
			continue
		parts.append("%s x%d" % [String(stack.item_id), stack.quantity])
		if parts.size() >= 5:
			break
	return "-" if parts.is_empty() else ", ".join(parts)
