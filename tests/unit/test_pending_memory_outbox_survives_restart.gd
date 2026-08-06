extends RefCounted

func run() -> bool:
	var provider := NPCCognitionSaveProvider.new()
	provider.backend_player_profile_id = "player"
	provider.world_save_id = "slot-01"
	provider.cache.enqueue_event({"player_profile_id": "player", "world_save_id": "slot-01", "npc_persistent_id": "mira", "event_type": "item_given"})
	var restored := NPCCognitionSaveProvider.new()
	var ok := restored.restore_save_data(provider.capture_save_data())
	var result := ok and restored.cache.pending_event_outbox.size() == 1
	provider.free()
	restored.free()
	return result
