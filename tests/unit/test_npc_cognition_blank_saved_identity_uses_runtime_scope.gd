extends RefCounted


func run() -> bool:
	var provider := NPCCognitionSaveProvider.new()
	provider.backend_player_profile_id = "runtime-player"
	provider.world_save_id = "runtime-slot"
	var stale_key := NPCMemoryCache.isolation_key("stale-player", "stale-slot", "mira")
	var stale_state := {
		"section_version": 1,
		"backend_player_profile_id": "",
		"world_save_id": "",
		"compact_memory_cache": {
			stale_key: [{"memory_id": "private-memory", "content": "private"}],
		},
		"conversation_session_index": {stale_key: "stale-session"},
		"pending_turn_outbox": [{
			"request_id": "stale-turn",
			"player_profile_id": "stale-player",
			"world_save_id": "stale-slot",
			"npc_persistent_id": "mira",
		}],
		"pending_event_outbox": [{
			"event_id": "stale-event",
			"player_profile_id": "stale-player",
			"world_save_id": "stale-slot",
			"npc_persistent_id": "mira",
		}],
		"last_sync_revision": 7,
		"sync_conflicts": [{"reason": "sync_scope_mismatch"}],
	}
	var restored := provider.restore_save_data(stale_state)
	var result := restored \
		and provider.backend_player_profile_id == "runtime-player" \
		and provider.world_save_id == "runtime-slot" \
		and _old_scope_was_discarded(provider, stale_key) \
		and provider.is_dirty()
	provider.clear_dirty()
	stale_state["backend_player_profile_id"] = "stale-player"
	stale_state["world_save_id"] = "stale-slot"
	result = result and provider.restore_save_data(stale_state) \
		and provider.backend_player_profile_id == "runtime-player" \
		and provider.world_save_id == "runtime-slot" \
		and _old_scope_was_discarded(provider, stale_key) \
		and provider.is_dirty()
	provider.free()
	return result


func _old_scope_was_discarded(provider: NPCCognitionSaveProvider, stale_key: String) -> bool:
	return provider.cache.memories_for("stale-player", "stale-slot", "mira").is_empty() \
		and provider.cache.get_session("stale-player", "stale-slot", "mira").is_empty() \
		and not provider.cache.to_dict().get("compact_memory_cache", {}).has(stale_key) \
		and provider.cache.pending_turn_outbox.is_empty() \
		and provider.cache.pending_event_outbox.is_empty() \
		and provider.cache.last_sync_revision == 0 \
		and provider.cache.sync_conflicts.is_empty()
