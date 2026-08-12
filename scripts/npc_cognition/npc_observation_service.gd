class_name NPCObservationService
extends RefCounted

var line_of_sight_filter: Callable

func can_witness(npc: NPCController, event: GameplayEvent, event_position: Vector3) -> bool:
	if npc == null or event == null or not npc.visible or npc.is_downed or npc.is_permanently_dead:
		return false
	if RegionIdUtil.normalize(npc.region_id) != RegionIdUtil.normalize(event.region_id): return false
	if npc.global_position.distance_to(event_position) > npc.npc_definition.witness_radius: return false
	if line_of_sight_filter.is_valid() and not bool(line_of_sight_filter.call(npc, event_position)): return false
	return true

func memory_candidate(npc_persistent_id: String, event: GameplayEvent) -> Dictionary:
	var high_salience_types := [&"npc_attacked", &"promise_made", &"quest_completed", &"entity_destroyed", &"encounter_discovered"]
	var subjects: Array[String] = [String(event.source_entity_id), String(event.target_entity_id)]
	if event.event_type == GameplayEventTypes.ENCOUNTER_DISCOVERED and event.definition_id != &"":
		subjects.append("encounter:%s" % String(event.definition_id))
	return {"owner_npc_persistent_id": npc_persistent_id, "source_type": "gameplay_event",
		"source_id": str(event.payload.get("event_id", "")), "event_type": String(event.event_type),
		"subject_node_ids": subjects,
		"occurred_at_game": event.world_time.duplicate(true),
		"salience": 0.95 if event.event_type in high_salience_types else 0.55,
		"visibility": str(event.payload.get("visibility", "witnessed"))}
