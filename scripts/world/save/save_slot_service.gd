extends Node
## Filesystem-level adventure save slot queries (no WorldSession required).

const DEFAULT_SLOT_ID: StringName = &"slot_01"
const WORLD_SAVE_VERSION: int = 4
const LEGACY_PATH := "user://world_save.json"
const LEGACY_BACKUP := "user://world_save_v3_imported.bak"


func get_slot_path(slot_id: StringName = DEFAULT_SLOT_ID) -> String:
	return "user://saves/%s/" % String(slot_id)


func has_adventure_save(slot_id: StringName = DEFAULT_SLOT_ID) -> bool:
	var summary := inspect_adventure_summary(slot_id)
	return bool(summary.get("valid", false))


func inspect_adventure_summary(slot_id: StringName = DEFAULT_SLOT_ID) -> Dictionary:
	var slot_path := get_slot_path(slot_id)
	var manifest_path := slot_path.path_join("manifest.json")
	if FileAccess.file_exists(manifest_path):
		var manifest := _read_json(manifest_path)
		if manifest.is_empty():
			return {"valid": false, "reason": "corrupt_manifest"}
		var version := int(manifest.get("save_version", 0))
		if version > WORLD_SAVE_VERSION:
			return {
				"valid": false,
				"reason": "future_version",
				"save_version": version,
				"player_name": str(manifest.get("player_name", "Traveler")),
			}
		if version < 1:
			return {"valid": false, "reason": "corrupt_manifest"}
		var player_path := slot_path.path_join("player.json")
		if not FileAccess.file_exists(player_path):
			return {"valid": false, "reason": "missing_player"}
		return {
			"valid": true,
			"reason": "",
			"save_version": version,
			"slot_id": String(slot_id),
			"player_name": str(manifest.get("player_name", "Traveler")),
			"region": str(manifest.get("current_region_id", "base:town")),
			"day": int(manifest.get("day", 1)),
			"hour": int(manifest.get("hour", 8)),
			"minute": int(manifest.get("minute", 0)),
		}
	# Legacy v3 fallback.
	if FileAccess.file_exists(LEGACY_PATH):
		var legacy := WorldSaveService.inspect_summary()
		if bool(legacy.get("valid", false)):
			legacy["reason"] = "legacy_v3"
			legacy["save_version"] = 3
			return legacy
	return {"valid": false, "reason": "missing"}


func clear_adventure_save(slot_id: StringName = DEFAULT_SLOT_ID) -> bool:
	var slot_path := get_slot_path(slot_id)
	_remove_dir(slot_path)
	# Also clear stray tmp/bak under slot parent.
	_clear_path_if_exists(LEGACY_PATH)
	_clear_path_if_exists(LEGACY_BACKUP)
	WorldSaveService.clear_world()
	return true


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


func _clear_path_if_exists(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _remove_dir(path: String) -> void:
	var global := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(global):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := path.path_join(name)
		if dir.current_is_dir():
			_remove_dir(full)
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(full))
		name = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(global)
