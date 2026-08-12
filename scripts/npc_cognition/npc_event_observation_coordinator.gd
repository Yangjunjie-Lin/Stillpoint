class_name NPCEventObservationCoordinator
extends Node
## Converts meaningful session-local gameplay facts into per-instance cognition outbox entries.

var cache: NPCMemoryCache
var player_profile_id: String = ""
var world_save_id: String = ""
var _event_bus: GameplayEventBus
var _entity_repository: WorldEntityRepository
var _observation := NPCObservationService.new()
var _event_counter: int = 0

func setup(
	p_cache: NPCMemoryCache,
	p_player_profile_id: String,
	p_world_save_id: String,
	event_bus: GameplayEventBus,
	entity_repository: WorldEntityRepository,
) -> void:
	cache = p_cache
	player_profile_id = p_player_profile_id
	world_save_id = p_world_save_id
	_entity_repository = entity_repository
	if _event_bus != null:
		_event_bus.unsubscribe(_on_gameplay_event)
	_event_bus = event_bus
	if _event_bus != null:
		_event_bus.subscribe(_on_gameplay_event)

func _exit_tree() -> void:
	if _event_bus != null:
		_event_bus.unsubscribe(_on_gameplay_event)
	_event_bus = null
	_entity_repository = null
	cache = null

func _on_gameplay_event(event: GameplayEvent) -> void:
	if cache == null or _entity_repository == null or not NPCMemoryEventAdapter.should_record(event):
		return
	# Player-private discoveries are not observable merely because an NPC happens
	# to be loaded in the same region.
	if str(event.payload.get("visibility", "witnessed")) == "private":
		return
	var event_id := _resolve_event_id(event)
	var event_position := _resolve_event_position(event)
	for entity in _entity_repository.get_loaded_entities_in_region(event.region_id):
		var npc := entity as NPCController
		if npc == null:
			continue
		var persistent_id := NPCIdentityResolver.resolve_persistent_id(npc)
		if persistent_id == &"":
			continue
		var participates := persistent_id == event.source_entity_id \
			or persistent_id == event.target_entity_id
		if not participates and not _observation.can_witness(npc, event, event_position):
			continue
		var scope := {
			"player_profile_id": player_profile_id,
			"world_save_id": world_save_id,
			"npc_persistent_id": String(persistent_id),
		}
		var outbox := NPCMemoryEventAdapter.to_outbox_event(scope, event)
		outbox.merge(_observation.memory_candidate(String(persistent_id), event), true)
		outbox["event_id"] = event_id
		outbox["source_id"] = event_id
		outbox["content"] = _event_content(event)
		cache.enqueue_event(outbox)

func _resolve_event_id(event: GameplayEvent) -> String:
	var existing := str(event.payload.get("event_id", ""))
	if not existing.is_empty():
		return existing
	_event_counter += 1
	existing = "event-%s-%d" % [Time.get_ticks_usec(), _event_counter]
	event.payload["event_id"] = existing
	return existing

func _resolve_event_position(event: GameplayEvent) -> Vector3:
	var data: Variant = event.payload.get("position", {})
	if data is Dictionary:
		var position := data as Dictionary
		if position.has("x") and position.has("y") and position.has("z"):
			return Vector3(float(position.x), float(position.y), float(position.z))
	for persistent_id in [event.source_entity_id, event.target_entity_id]:
		var node := _entity_repository.get_loaded_entity(persistent_id) as Node3D
		if node != null:
			return node.global_position
	return Vector3.ZERO

func _event_content(event: GameplayEvent) -> String:
	return "%s: %s -> %s in %s" % [
		String(event.event_type),
		String(event.source_entity_id),
		String(event.target_entity_id),
		String(event.region_id),
	]
