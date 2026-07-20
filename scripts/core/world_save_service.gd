extends Node
## Partitioned world save (schema v3) for life-sim RPG state.

const WORLD_SAVE_VERSION: int = 3
const WORLD_PATH := "user://world_save.json"

var _test_fail_replace_count: int = 0


func save_world(data: Dictionary) -> bool:
	var payload := data.duplicate(true)
	payload["version"] = WORLD_SAVE_VERSION
	payload["saved_at"] = int(Time.get_unix_time_from_system())
	for section in [
		"profile", "player", "world", "relationships", "quests",
		"inventory", "pets", "mounts", "regions",
	]:
		if not payload.has(section):
			payload[section] = {}
	return _write_json(WORLD_PATH, payload)


func load_world() -> Dictionary:
	var raw := _read_json(WORLD_PATH)
	if raw.is_empty():
		return {}
	var version := int(raw.get("version", 0))
	if version > WORLD_SAVE_VERSION:
		push_warning("WorldSaveService: future save version %d" % version)
		return {}
	if version < WORLD_SAVE_VERSION:
		raw = _migrate_world(raw, version)
	return raw


func has_world_save() -> bool:
	return not load_world().is_empty()


func clear_world() -> bool:
	if not FileAccess.file_exists(WORLD_PATH):
		return true
	return DirAccess.remove_absolute(ProjectSettings.globalize_path(WORLD_PATH)) == OK


func validate_schema(payload: Dictionary) -> bool:
	if int(payload.get("version", 0)) != WORLD_SAVE_VERSION:
		return false
	for section in ["profile", "player", "world", "relationships", "quests", "inventory", "pets", "mounts", "regions"]:
		if not payload.has(section):
			return false
	return true


func _migrate_world(payload: Dictionary, from_version: int) -> Dictionary:
	var migrated := payload.duplicate(true)
	if from_version < 3:
		for section in ["profile", "player", "world", "relationships", "quests", "inventory", "pets", "mounts", "regions"]:
			if not migrated.has(section):
				migrated[section] = {}
		migrated["version"] = WORLD_SAVE_VERSION
	return migrated


func _write_json(path: String, payload: Dictionary) -> bool:
	var global_path := ProjectSettings.globalize_path(path)
	var tmp_path := "%s.tmp" % global_path
	var bak_path := "%s.bak" % global_path
	var text := JSON.stringify(payload, "\t")
	var file := FileAccess.open(tmp_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(text)
	file.close()
	if FileAccess.file_exists(global_path):
		if FileAccess.file_exists(bak_path):
			DirAccess.remove_absolute(bak_path)
		if _rename_absolute(global_path, bak_path) != OK:
			push_error("WorldSaveService: cannot backup %s" % path)
			DirAccess.remove_absolute(tmp_path)
			return false
	if _test_fail_replace_count > 0:
		_test_fail_replace_count -= 1
		DirAccess.remove_absolute(tmp_path)
		if FileAccess.file_exists(bak_path):
			_rename_absolute(bak_path, global_path)
		return false
	if _rename_absolute(tmp_path, global_path) != OK:
		if FileAccess.file_exists(bak_path):
			_rename_absolute(bak_path, global_path)
		return false
	if FileAccess.file_exists(bak_path):
		DirAccess.remove_absolute(bak_path)
	return true


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


func _rename_absolute(source: String, target: String) -> Error:
	return DirAccess.rename_absolute(source, target)
