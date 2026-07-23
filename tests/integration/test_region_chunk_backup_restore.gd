extends RefCounted


func run() -> bool:
	var coordinator := WorldSaveCoordinator.new()
	var payload := {
		"region_id": "base:town",
		"region_state_version": 1,
		"entities": {},
		"destroyed_entities": [],
		"spawn_states": {},
		"custom_state": {"backup_marker": true},
	}
	if not coordinator._write_json("user://saves/slot_01/regions/base_town.json", payload):
		push_error("initial chunk write failed")
		coordinator.clear_save()
		coordinator.free()
		return false

	var global_path := ProjectSettings.globalize_path("user://saves/slot_01/regions/base_town.json")
	var bak_path := global_path + ".bak"
	if FileAccess.file_exists(global_path):
		if FileAccess.file_exists(bak_path):
			DirAccess.remove_absolute(bak_path)
		DirAccess.rename_absolute(global_path, bak_path)

	var corrupt := FileAccess.open(global_path, FileAccess.WRITE)
	corrupt.store_string("{broken")
	corrupt.close()

	var recovered := coordinator._read_json_with_backup("user://saves/slot_01/regions/base_town.json")
	if not bool(recovered.get("custom_state", {}).get("backup_marker", false)):
		push_error("region chunk not recovered from .bak")
		coordinator.clear_save()
		coordinator.free()
		return false

	coordinator.clear_save()
	coordinator.free()
	return true
