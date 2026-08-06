class_name NPCMemoryEventAdapter
extends RefCounted

const REMEMBERED_EVENTS: Array[StringName] = [
	&"npc_talked", &"npc_attacked", &"item_given", &"item_received",
	&"quest_started", &"quest_completed", &"quest_failed", &"region_entered",
	&"entity_destroyed", &"relationship_changed", &"trade_completed", &"promise_made",
]

static func should_record(event: GameplayEvent) -> bool:
	return event != null and event.event_type in REMEMBERED_EVENTS

static func to_outbox_event(scope: Dictionary, event: GameplayEvent) -> Dictionary:
	if not should_record(event): return {}
	var result := scope.duplicate(true)
	result.merge({"event_type": String(event.event_type),
		"source_entity_id": String(event.source_entity_id),
		"target_entity_id": String(event.target_entity_id),
		"definition_id": String(event.definition_id), "region_id": String(event.region_id),
		"amount": event.amount, "payload": event.payload.duplicate(true),
		"world_time": event.world_time.duplicate(true)}, true)
	return result
