extends RefCounted


func run() -> bool:
	var coordinator := WorldSaveCoordinator.new()
	coordinator._write_manifest_data(&"base:town", &"spawn")
	var manifest := coordinator._read_json("user://saves/slot_01/manifest.json")
	var ok := int(manifest.get("save_version", 0)) == 4
	ok = ok and str(manifest.get("game_version", "")) == str(
		ProjectSettings.get_setting("application/config/version", "")
	)
	ok = ok and manifest.get("current_region_id", "") == "base:town"
	coordinator.clear_save()
	coordinator.free()
	return ok
