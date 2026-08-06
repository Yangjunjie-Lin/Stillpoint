extends RefCounted

func run() -> bool:
	var provider := NPCCognitionSaveProvider.new()
	provider.backend_player_profile_id = "player"
	provider.world_save_id = "slot-01"
	provider.cache.remember("player", "slot-01", "mira", {"memory_id": "m1", "content": "blue"})
	var restored := NPCCognitionSaveProvider.new()
	var ok := restored.restore_save_data(provider.capture_save_data())
	var result := ok and restored.cache.memories_for("player", "slot-01", "mira").size() == 1
	provider.free()
	restored.free()
	return result
