extends RefCounted


func run() -> bool:
	var coordinator := WorldSaveCoordinator.new()
	var path := "user://saves/slot_01/world_flags.json"
	var absolute_path := ProjectSettings.globalize_path(path)
	var parent_path := absolute_path.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(parent_path) != OK:
		push_error("empty JSON primary test could not create save directory")
		coordinator.free()
		return false

	var primary := FileAccess.open(absolute_path, FileAccess.WRITE)
	var backup := FileAccess.open(absolute_path + ".bak", FileAccess.WRITE)
	if primary == null or backup == null:
		push_error("empty JSON primary test could not create fixtures")
		if primary != null:
			primary.close()
		if backup != null:
			backup.close()
		coordinator.clear_save()
		coordinator.free()
		return false
	primary.store_string("{}")
	primary.close()
	backup.store_string('{"stale_flag": true}')
	backup.close()

	var restored := coordinator._read_json_with_backup(path)
	var ok := restored.is_empty() and not restored.has("stale_flag")
	if not ok:
		push_error("valid empty JSON primary was replaced by stale backup data")
	coordinator.clear_save()
	coordinator.free()
	return ok
