class_name WorldSaveCoordinator
extends Node
## Orchestrates Save v4 chunked world persistence.

const WORLD_SAVE_VERSION: int = 4
const SLOT_PATH := "user://saves/slot_01/"
const LEGACY_PATH := "user://world_save.json"
const LEGACY_BACKUP := "user://world_save_v3_imported.bak"

var _dirty_sections: Dictionary = {}
var _last_save_result: String = "none"
var _entity_repository: WorldEntityRepository
var _region_service: RegionRuntimeService
var _world_flags: WorldFlagService
var _session: Node


func setup(
	session: Node,
	repository: WorldEntityRepository,
	region_service: RegionRuntimeService,
	flags: WorldFlagService,
) -> void:
	_session = session
	_entity_repository = repository
	_region_service = region_service
	_world_flags = flags


func mark_dirty(section_id: StringName) -> void:
	_dirty_sections[section_id] = true


func mark_region_dirty(region_id: StringName) -> void:
	_dirty_sections[StringName("region:%s" % RegionIdUtil.chunk_filename(region_id))] = true


func save_dirty_sections() -> bool:
	if _dirty_sections.is_empty():
		return true
	var ok := true
	for key in _dirty_sections.keys():
		if not _save_section(String(key)):
			ok = false
	if ok:
		_dirty_sections.clear()
		_write_manifest()
	_last_save_result = "ok" if ok else "partial_failure"
	return ok


func save_all() -> bool:
	_dirty_sections = {
		"profile": true,
		"player": true,
		"global_world": true,
		"relationships": true,
		"quests": true,
		"world_flags": true,
		"companions": true,
	}
	if _region_service != null:
		var chunk := _region_service.capture_current_region_chunk()
		_region_service.set_region_chunk(_region_service.get_current_region_id(), chunk)
		mark_region_dirty(_region_service.get_current_region_id())
	for region_id in _get_known_regions():
		mark_region_dirty(region_id)
	return save_dirty_sections()


func has_save() -> bool:
	return FileAccess.file_exists(SLOT_PATH + "manifest.json") or FileAccess.file_exists(LEGACY_PATH)


func restore_session() -> bool:
	if FileAccess.file_exists(SLOT_PATH + "manifest.json"):
		return _restore_v4()
	if FileAccess.file_exists(LEGACY_PATH):
		return _migrate_v3_to_v4()
	return false


func inspect_summary() -> Dictionary:
	if FileAccess.file_exists(SLOT_PATH + "manifest.json"):
		var manifest := _read_json(SLOT_PATH + "manifest.json")
		if manifest.is_empty():
			return {"valid": false}
		return {
			"valid": true,
			"player_name": str(manifest.get("player_name", "Traveler")),
			"region": str(manifest.get("current_region_id", "base:town")),
			"day": int(manifest.get("day", 1)),
			"hour": int(manifest.get("hour", 8)),
			"minute": int(manifest.get("minute", 0)),
		}
	return WorldSaveService.inspect_summary()


func clear_save() -> void:
	_remove_dir(SLOT_PATH)
	WorldSaveService.clear_world()


func get_last_save_result() -> String:
	return _last_save_result


func _restore_v4() -> bool:
	var manifest := _read_json(SLOT_PATH + "manifest.json")
	if manifest.is_empty():
		return false
	var version := int(manifest.get("save_version", 0))
	if version > WORLD_SAVE_VERSION:
		push_warning("WorldSaveCoordinator: future save version")
		return false
	GameManager.player_name = str(manifest.get("player_name", "Traveler"))
	var player_data := _read_json(SLOT_PATH + "player.json")
	if player_data.is_empty():
		return false
	var global_data := _read_json(SLOT_PATH + "global_world.json")
	WorldTimeService.from_dict(global_data.get("world_time", {}))
	RelationshipService.from_dict(_read_json(SLOT_PATH + "relationships.json"))
	QuestManager.from_dict(_read_json(SLOT_PATH + "quests.json"))
	if _world_flags != null:
		_world_flags.from_dict(_read_json(SLOT_PATH + "world_flags.json"))
	var region_id := StringName(str(manifest.get("current_region_id", "base:town")))
	var spawn_id := StringName(str(manifest.get("current_spawn_id", "spawn")))
	if _session != null and _session.has_method("restore_player_data"):
		_session.call("restore_player_data", player_data)
	if _region_service != null:
		for file_name in _list_region_files():
			var chunk := _read_json(SLOT_PATH + "regions/" + file_name)
			if not chunk.is_empty():
				_region_service.set_region_chunk(
					StringName(str(chunk.get("region_id", ""))),
					chunk,
				)
		_region_service.enter_region(region_id, spawn_id)
	var companions := _read_json(SLOT_PATH + "companions.json")
	if _session != null and _session.has_method("restore_companions"):
		_session.call("restore_companions", companions)
	return true


func _migrate_v3_to_v4() -> bool:
	var raw := _read_json(LEGACY_PATH)
	if raw.is_empty():
		return false
	_remove_dir(SLOT_PATH)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SLOT_PATH + "regions"))
	_write_json(SLOT_PATH + "profile.json", raw.get("profile", {}))
	_write_json(SLOT_PATH + "player.json", {
		"player": raw.get("player", {}),
		"inventory": raw.get("inventory", {}),
	})
	_write_json(SLOT_PATH + "global_world.json", {
		"world_time": raw.get("world", {}),
		"regions": raw.get("regions", {}),
	})
	_write_json(SLOT_PATH + "relationships.json", raw.get("relationships", {}))
	_write_json(SLOT_PATH + "quests.json", raw.get("quests", {}))
	_write_json(SLOT_PATH + "world_flags.json", {})
	_write_json(SLOT_PATH + "companions.json", {
		"pets": raw.get("pets", {}),
		"mounts": raw.get("mounts", {}),
	})
	_migrate_v3_entities_to_chunks(raw)
	var regions: Dictionary = raw.get("regions", {})
	var current := RegionIdUtil.normalize(StringName(str(regions.get("current", "town"))))
	_write_manifest_data(current, &"spawn", raw)
	var global_legacy := ProjectSettings.globalize_path(LEGACY_PATH)
	var backup := ProjectSettings.globalize_path(LEGACY_BACKUP)
	if FileAccess.file_exists(LEGACY_PATH):
		if FileAccess.file_exists(LEGACY_BACKUP):
			DirAccess.remove_absolute(backup)
		DirAccess.rename_absolute(global_legacy, backup)
	return _restore_v4()


func _migrate_v3_entities_to_chunks(raw: Dictionary) -> void:
	var npcs: Dictionary = raw.get("npcs", {})
	var interactables: Dictionary = raw.get("interactables", {})
	var mapping := SaveV3MigrationMapping.INTERACTABLE_REGION_MAP
	for npc_key in npcs.keys():
		var npc_data: Dictionary = npcs[npc_key]
		var region := RegionIdUtil.normalize(StringName(str(npc_data.get("region_id", "base:town"))))
		_append_entity_to_chunk(region, SaveV3MigrationMapping.npc_persistent_id(npc_key), npc_key, npc_data)
	for iname in interactables.keys():
		var idata: Dictionary = interactables[iname]
		var region2 := RegionIdUtil.normalize(mapping.get(iname, &"base:town"))
		var pid := SaveV3MigrationMapping.interactable_persistent_id(iname, region2)
		_append_entity_to_chunk(region2, pid, &"", idata)


func _append_entity_to_chunk(region_id: StringName, persistent_id: StringName, definition_id: StringName, data: Dictionary) -> void:
	var fname := SLOT_PATH + "regions/%s.json" % RegionIdUtil.chunk_filename(region_id)
	var chunk := _read_json(fname)
	if chunk.is_empty():
		chunk = {
			"region_id": String(region_id),
			"region_state_version": 1,
			"entities": {},
			"destroyed_entities": [],
			"spawn_states": {},
			"custom_state": {},
		}
	var entities: Dictionary = chunk.get("entities", {})
	entities[String(persistent_id)] = {
		"persistent_id": String(persistent_id),
		"definition_id": String(definition_id),
		"region_id": String(region_id),
		"state_version": 1,
		"components": {"entity": data},
	}
	chunk["entities"] = entities
	_write_json(fname, chunk)


func _write_manifest_data(region_id: StringName, spawn_id: StringName, raw: Dictionary = {}) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SLOT_PATH))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SLOT_PATH + "regions/"))
	var profile: Dictionary = raw.get("profile", {}) if not raw.is_empty() else {}
	var world: Dictionary = raw.get("world", {}) if not raw.is_empty() else WorldTimeService.to_dict()
	_write_json(SLOT_PATH + "manifest.json", {
		"save_version": WORLD_SAVE_VERSION,
		"game_version": "0.7.0",
		"slot_id": "slot_01",
		"created_at": int(Time.get_unix_time_from_system()),
		"updated_at": int(Time.get_unix_time_from_system()),
		"player_name": str(profile.get("player_name", GameManager.player_name)),
		"current_region_id": String(region_id),
		"current_spawn_id": String(spawn_id),
		"day": int(world.get("day", 1)),
		"hour": int(world.get("hour", 8)),
		"minute": int(world.get("minute", 0)),
		"play_time_seconds": 0,
		"content_packs": {},
		"region_chunks": {},
		"checksum_version": 1,
	})


func _write_manifest() -> void:
	if _session == null or _region_service == null:
		return
	_write_manifest_data(
		_region_service.get_current_region_id(),
		&"spawn",
	)


func _save_section(section_key: String) -> bool:
	match section_key:
		"profile":
			return _write_json(SLOT_PATH + "profile.json", {"player_name": GameManager.player_name})
		"player":
			if _session == null:
				return false
			return _write_json(SLOT_PATH + "player.json", _session.call("capture_player_data"))
		"global_world":
			return _write_json(SLOT_PATH + "global_world.json", {
				"world_time": WorldTimeService.to_dict(),
				"discovered_regions": _session.get("discovered_regions") if _session else [],
				"current_region_id": String(_region_service.get_current_region_id()) if _region_service else "",
			})
		"relationships":
			return _write_json(SLOT_PATH + "relationships.json", RelationshipService.to_dict())
		"quests":
			return _write_json(SLOT_PATH + "quests.json", QuestManager.to_dict())
		"world_flags":
			return _write_json(SLOT_PATH + "world_flags.json", _world_flags.to_dict() if _world_flags else {})
		"companions":
			if _session == null:
				return false
			return _write_json(SLOT_PATH + "companions.json", _session.call("capture_companions"))
		_:
			if section_key.begins_with("region:"):
				var fname := section_key.trim_prefix("region:")
				var region_id := StringName("base:%s" % fname.replace("_", ":").replace("base::", "base:"))
				if _region_service != null:
					var chunk := _region_service.get_region_chunk(region_id)
					if chunk.is_empty():
						chunk = _region_service.capture_current_region_chunk()
					DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SLOT_PATH + "regions"))
					return _write_json(SLOT_PATH + "regions/%s.json" % fname, chunk)
	return true


func _get_known_regions() -> Array[StringName]:
	return [&"base:town", &"base:wilderness", &"base:dungeon"]


func _list_region_files() -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(SLOT_PATH + "regions")
	if dir == null:
		return result
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if f.ends_with(".json"):
			result.append(f)
		f = dir.get_next()
	dir.list_dir_end()
	return result


func _write_json(path: String, payload: Dictionary) -> bool:
	var global_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(global_path.get_base_dir())
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
		DirAccess.rename_absolute(global_path, bak_path)
	if DirAccess.rename_absolute(tmp_path, global_path) != OK:
		if FileAccess.file_exists(bak_path):
			DirAccess.rename_absolute(bak_path, global_path)
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
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed


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
