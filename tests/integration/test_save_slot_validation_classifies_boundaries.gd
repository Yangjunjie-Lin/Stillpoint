extends RefCounted


func run() -> bool:
	var slot := "user://saves/slot_01/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(slot))
	var manifest := {
		"save_version": 4,
		"current_region_id": "base:town",
		"region_chunks": {},
	}
	_write_json(slot + "manifest.json", manifest)

	var missing_player := SaveSlotService.validate_adventure_save()
	var ok := str(missing_player.get("reason", "")) == "missing_player"
	_write_text(slot + "player.json", "{corrupt")
	var corrupt_player := SaveSlotService.validate_adventure_save()
	ok = ok and str(corrupt_player.get("reason", "")) == "corrupt_player"

	_write_json(slot + "player.json", {"player": {}, "inventory": {}})
	var defaulted_global := SaveSlotService.validate_adventure_save()
	ok = ok and bool(defaulted_global.get("valid", false))
	ok = ok and (defaulted_global.get("warnings", []) as Array).has(
		"global_world_defaults_used"
	)

	_write_json(slot + "manifest.json.bak", manifest)
	_write_text(slot + "manifest.json", "{corrupt")
	var manifest_backup := SaveSlotService.validate_adventure_save()
	ok = ok and bool(manifest_backup.get("valid", false))
	ok = ok and bool(manifest_backup.get("used_manifest_backup", false))

	var future := manifest.duplicate(true)
	future["save_version"] = 99
	_write_json(slot + "manifest.json", future)
	var future_result := SaveSlotService.validate_adventure_save()
	ok = ok and not bool(future_result.get("valid", true))
	ok = ok and str(future_result.get("reason", "")) == "future_version"
	if not ok:
		push_error("Save Slot boundary classifications were inconsistent")
	return ok


func _write_json(path: String, data: Dictionary) -> void:
	_write_text(path, JSON.stringify(data))


func _write_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()
