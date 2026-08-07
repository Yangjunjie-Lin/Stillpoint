class_name NPCMemoryCache
extends RefCounted
## Small offline cache/outbox only. The backend database remains authoritative.

signal changed(reason: StringName)

const SECTION_VERSION := 1
const MAX_CACHE_PER_NPC := 32

var _memories: Dictionary = {}
var _session_index: Dictionary = {}
var pending_event_outbox: Array[Dictionary] = []
var pending_turn_outbox: Array[Dictionary] = []
var last_sync_revision: int = 0
var sync_conflicts: Array[Dictionary] = []

static func isolation_key(
	player_profile_id: String,
	world_save_id: String,
	npc_persistent_id: String,
) -> String:
	if player_profile_id.is_empty() or world_save_id.is_empty() or npc_persistent_id.is_empty():
		return ""
	return "%s\u001f%s\u001f%s" % [player_profile_id, world_save_id, npc_persistent_id]

func remember(
	player_profile_id: String,
	world_save_id: String,
	npc_persistent_id: String,
	memory: Dictionary,
) -> bool:
	var key := isolation_key(player_profile_id, world_save_id, npc_persistent_id)
	if key.is_empty() or str(memory.get("memory_id", "")).is_empty():
		return false
	var bucket: Array = _memories.get(key, [])
	var memory_id := str(memory.get("memory_id"))
	for index in bucket.size():
		if str((bucket[index] as Dictionary).get("memory_id", "")) == memory_id:
			if bucket[index] == memory:
				return true
			bucket[index] = memory.duplicate(true)
			_memories[key] = bucket
			changed.emit(&"memory_updated")
			return true
	bucket.append(memory.duplicate(true))
	if bucket.size() > MAX_CACHE_PER_NPC:
		bucket = bucket.slice(bucket.size() - MAX_CACHE_PER_NPC)
	_memories[key] = bucket
	changed.emit(&"memory_added")
	return true

func memories_for(
	player_profile_id: String,
	world_save_id: String,
	npc_persistent_id: String,
) -> Array[Dictionary]:
	var key := isolation_key(player_profile_id, world_save_id, npc_persistent_id)
	var result: Array[Dictionary] = []
	for memory in _memories.get(key, []):
		if memory is Dictionary: result.append((memory as Dictionary).duplicate(true))
	return result

func set_session(
	player_profile_id: String,
	world_save_id: String,
	npc_persistent_id: String,
	session_id: String,
) -> bool:
	var key := isolation_key(player_profile_id, world_save_id, npc_persistent_id)
	if key.is_empty() or session_id.is_empty(): return false
	if str(_session_index.get(key, "")) == session_id:
		return true
	_session_index[key] = session_id
	changed.emit(&"session_updated")
	return true

func get_session(player_profile_id: String, world_save_id: String, npc_persistent_id: String) -> String:
	return str(_session_index.get(isolation_key(player_profile_id, world_save_id, npc_persistent_id), ""))

func enqueue_turn(turn: Dictionary) -> bool:
	if not _valid_scope(turn): return false
	var request_id := str(turn.get("request_id", ""))
	if request_id.is_empty(): return false
	for existing in pending_turn_outbox:
		if str(existing.get("request_id", "")) == request_id: return true
	pending_turn_outbox.append(turn.duplicate(true))
	changed.emit(&"turn_outbox_added")
	return true

func enqueue_event(event: Dictionary) -> bool:
	if not _valid_scope(event): return false
	var event_id := str(event.get("event_id", event.get("source_id", "")))
	if event_id.is_empty(): return false
	for existing in pending_event_outbox:
		if str(existing.get("event_id", existing.get("source_id", ""))) == event_id:
			return true
	pending_event_outbox.append(event.duplicate(true))
	changed.emit(&"event_outbox_added")
	return true

func acknowledge_turn(request_id: String) -> bool:
	var before := pending_turn_outbox.size()
	pending_turn_outbox = pending_turn_outbox.filter(func(item: Dictionary) -> bool:
		return str(item.get("request_id", "")) != request_id)
	if pending_turn_outbox.size() != before:
		changed.emit(&"turn_outbox_acked")
		return true
	return false

func apply_sync_ack(response: Dictionary) -> void:
	var accepted_turns: Array = response.get("accepted_turn_ids", [])
	var accepted_events: Array = response.get("accepted_event_ids", [])
	var before_turns := pending_turn_outbox.size()
	var before_events := pending_event_outbox.size()
	pending_turn_outbox = pending_turn_outbox.filter(func(item: Dictionary) -> bool:
		return not accepted_turns.has(str(item.get("request_id", ""))))
	pending_event_outbox = pending_event_outbox.filter(func(item: Dictionary) -> bool:
		return not accepted_events.has(str(item.get("event_id", item.get("source_id", "")))))
	var new_revision := maxi(0, int(response.get("revision", last_sync_revision)))
	var new_conflicts := _dict_array(response.get("conflicts", []))
	var mutated := before_turns != pending_turn_outbox.size() \
		or before_events != pending_event_outbox.size() \
		or new_revision != last_sync_revision \
		or new_conflicts != sync_conflicts
	last_sync_revision = new_revision
	sync_conflicts = new_conflicts
	if mutated:
		changed.emit(&"sync_ack_applied")

func delete_npc(player_profile_id: String, world_save_id: String, npc_persistent_id: String) -> void:
	var key := isolation_key(player_profile_id, world_save_id, npc_persistent_id)
	_memories.erase(key)
	_session_index.erase(key)
	pending_turn_outbox = pending_turn_outbox.filter(func(item: Dictionary) -> bool:
		return isolation_key(str(item.get("player_profile_id", "")), str(item.get("world_save_id", "")), str(item.get("npc_persistent_id", ""))) != key)
	pending_event_outbox = pending_event_outbox.filter(func(item: Dictionary) -> bool:
		return isolation_key(str(item.get("player_profile_id", "")), str(item.get("world_save_id", "")), str(item.get("npc_persistent_id", ""))) != key)
	changed.emit(&"npc_memory_deleted")

func delete_player(player_profile_id: String) -> void:
	for key in _memories.keys():
		if str(key).begins_with(player_profile_id + "\u001f"):
			_memories.erase(key)
			_session_index.erase(key)
	pending_turn_outbox = pending_turn_outbox.filter(func(item: Dictionary) -> bool:
		return str(item.get("player_profile_id", "")) != player_profile_id)
	pending_event_outbox = pending_event_outbox.filter(func(item: Dictionary) -> bool:
		return str(item.get("player_profile_id", "")) != player_profile_id)
	changed.emit(&"player_memory_deleted")

func to_dict() -> Dictionary:
	return {"section_version": SECTION_VERSION, "last_sync_revision": last_sync_revision,
		"conversation_session_index": _session_index.duplicate(true),
		"compact_memory_cache": _memories.duplicate(true),
		"pending_event_outbox": pending_event_outbox.duplicate(true),
		"pending_turn_outbox": pending_turn_outbox.duplicate(true),
		"sync_conflicts": sync_conflicts.duplicate(true)}

func from_dict(data: Dictionary) -> bool:
	if data.is_empty():
		clear(false)
		return true
	if int(data.get("section_version", SECTION_VERSION)) > SECTION_VERSION: return false
	var memory_data: Variant = data.get("compact_memory_cache", {})
	var session_data: Variant = data.get("conversation_session_index", {})
	if typeof(memory_data) != TYPE_DICTIONARY or typeof(session_data) != TYPE_DICTIONARY: return false
	_memories = (memory_data as Dictionary).duplicate(true)
	_session_index = (session_data as Dictionary).duplicate(true)
	last_sync_revision = maxi(0, int(data.get("last_sync_revision", 0)))
	pending_event_outbox = _dict_array(data.get("pending_event_outbox", []))
	pending_turn_outbox = _dict_array(data.get("pending_turn_outbox", []))
	sync_conflicts = _dict_array(data.get("sync_conflicts", []))
	return true

func export_player_data(player_profile_id: String) -> Dictionary:
	var exported := to_dict()
	var memories := {}
	var sessions := {}
	for key in _memories.keys():
		if str(key).begins_with(player_profile_id + "\u001f"):
			memories[key] = _memories[key]
			sessions[key] = _session_index.get(key, "")
	exported["compact_memory_cache"] = memories
	exported["conversation_session_index"] = sessions
	return exported

func clear(notify: bool = true) -> void:
	_memories.clear()
	_session_index.clear()
	pending_event_outbox.clear()
	pending_turn_outbox.clear()
	sync_conflicts.clear()
	last_sync_revision = 0
	if notify:
		changed.emit(&"cache_cleared")

func _valid_scope(item: Dictionary) -> bool:
	return not isolation_key(str(item.get("player_profile_id", "")), str(item.get("world_save_id", "")), str(item.get("npc_persistent_id", ""))).is_empty()

func _dict_array(value: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if value is Array:
		for item in value:
			if item is Dictionary: result.append((item as Dictionary).duplicate(true))
	return result
