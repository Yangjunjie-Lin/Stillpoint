extends RefCounted

func run() -> bool:
	var provider := NPCCognitionSaveProvider.new()
	provider.backend_player_profile_id = "runtime-player"
	provider.world_save_id = "runtime-slot"
	var result := provider.restore_save_data({}) \
		and provider.backend_player_profile_id == "runtime-player" \
		and provider.world_save_id == "runtime-slot" \
		and provider.cache.memories_for("runtime-player", "runtime-slot", "mira").is_empty()
	provider.free()
	return result
