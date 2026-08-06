extends RefCounted

func run() -> bool:
	var provider := NPCCognitionSaveProvider.new()
	var result := provider.restore_save_data({"section_version": 1}) and provider.cache.memories_for("player", "slot-01", "mira").is_empty()
	provider.free()
	return result
