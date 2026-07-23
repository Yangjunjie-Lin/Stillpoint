class_name WorldSaveCoordinator
extends Node
## Orchestrates Save v4 chunked world persistence with dirty tracking.

const WORLD_SAVE_VERSION: int = 4
const SLOT_PATH := "user://saves/slot_01/"
const LEGACY_PATH := "user://world_save.json"
const LEGACY_BACKUP := "user://world_save_v3_imported.bak"

## section_id (StringName) -> true
var _dirty_sections: Dictionary = {}
## region_id (StringName) -> true
var _dirty_regions: Dictionary = {}
## region_id -> chunk filename mapping for manifest
var _region_chunk_map: Dictionary = {}
var _last_save_result: String = "none"
var _entity_repository: WorldEntityRepository
var _region_service: RegionRuntimeService
var _world_flags: WorldFlagService
var _session: Node
var _id_counters: Dictionary = {}


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
	if _region_service != null and not _region_service.region_chunk_captured.is_connected(_on_region_chunk_captured):
		_region_service.region_chunk_captured.connect(_on_region_chunk_captured)
	_connect_dirty_signals()


func mark_dirty(section_id: StringName) -> void:
	_dirty_sections[section_id] = true


func mark_region_dirty(region_id: StringName) -> void:
	var norm := RegionIdUtil.normalize(region_id)
	if norm == &"":
		return
	_dirty_regions[norm] = true
	_region_chunk_map[String(norm)] = RegionIdUtil.to_chunk_filename(norm) + ".json"


func save_dirty_sections() -> bool:
	_absorb_repository_dirty_regions()
	if _dirty_sections.is_empty() and _dirty_regions.is_empty():
		return true
	var all_ok := true
	var cleared_sections: Array[StringName] = []
	for key in _dirty_sections.keys():
		if _save_named_section(StringName(str(key))):
			cleared_sections.append(StringName(str(key)))
		else:
			all_ok = false
	for section_id in cleared_sections:
		_dirty_sections.erase(section_id)
	var cleared_regions: Array[StringName] = []
	for region_id in _dirty_regions.keys():
		if _save_region_chunk(region_id):
			cleared_regions.append(region_id)
			if _entity_repository != null:
				_entity_repository.clear_dirty_region(region_id)
		else:
			all_ok = false
	for region_id in cleared_regions:
		_dirty_regions.erase(region_id)
	_write_manifest()
	_last_save_result = "ok" if all_ok else "partial_failure"
	return all_ok


func save_all() -> bool:
	_dirty_sections = {
		&"profile": true,
		&"player": true,
		&"global_world": true,
		&"relationships": true,
		&"quests": true,
		&"world_flags": true,
		&"companions": true,
	}
	if _region_service != null:
		var current := _region_service.get_current_region_id()
		if current != &"":
			var chunk := _region_service.capture_current_region_chunk()
			_region_service.set_region_chunk(current, chunk)
			mark_region_dirty(current)
		for region_id in _region_service.get_cached_region_ids():
			mark_region_dirty(region_id)
	for region_id in _get_known_regions():
		mark_region_dirty(region_id)
	return save_dirty_sections()


func has_save() -> bool:
	return SaveSlotService.has_adventure_save()


func restore_session() -> bool:
	if FileAccess.file_exists(SLOT_PATH + "manifest.json"):
		return _restore_v4()
	if FileAccess.file_exists(LEGACY_PATH):
		return _migrate_v3_to_v4()
	return false


func inspect_summary() -> Dictionary:
	return SaveSlotService.inspect_adventure_summary()


func clear_save() -> void:
	SaveSlotService.clear_adventure_save()


func get_last_save_result() -> String:
	return _last_save_result


func next_runtime_id(region_id: StringName, category: StringName) -> StringName:
	var key := "%s:%s" % [String(RegionIdUtil.normalize(region_id)), String(category)]
	var counter := int(_id_counters.get(key, 0)) + 1
	_id_counters[key] = counter
	mark_dirty(&"global_world")
	return PersistentIdGenerator.next_instance_id(region_id, category, counter)


func _on_region_chunk_captured(region_id: StringName, chunk: Dictionary) -> void:
	if _region_service != null:
		_region_service.set_region_chunk(region_id, chunk)
	mark_region_dirty(region_id)


func _absorb_repository_dirty_regions() -> void:
	if _entity_repository == null:
		return
	for region_id in _entity_repository.peek_dirty_regions():
		mark_region_dirty(region_id)


func _connect_dirty_signals() -> void:
	if RelationshipService.has_signal("affinity_changed"):
		if not RelationshipService.affinity_changed.is_connected(_on_relationships_dirty):
			RelationshipService.affinity_changed.connect(_on_relationships_dirty)
	if QuestManager.has_signal("quest_state_changed"):
		if not QuestManager.quest_state_changed.is_connected(_on_quests_dirty):
			QuestManager.quest_state_changed.connect(_on_quests_dirty)
	if _world_flags != null and _world_flags.has_signal("flag_changed"):
		if not _world_flags.flag_changed.is_connected(_on_flags_dirty):
			_world_flags.flag_changed.connect(_on_flags_dirty)


func _on_relationships_dirty(_a = null, _b = null, _c = null) -> void:
	mark_dirty(&"relationships")


func _on_quests_dirty(_a = null, _b = null) -> void:
	mark_dirty(&"quests")


func _on_flags_dirty(_a = null, _b = null) -> void:
	mark_dirty(&"world_flags")


func _restore_v4() -> bool:
	var manifest := _read_json_with_backup(SLOT_PATH + "manifest.json")
	if manifest.is_empty():
		return false
	var version := int(manifest.get("save_version", 0))
	if version > WORLD_SAVE_VERSION:
		push_warning("WorldSaveCoordinator: future save version")
		return false
	GameManager.player_name = str(manifest.get("player_name", "Traveler"))
	var player_data := _read_json_with_backup(SLOT_PATH + "player.json")
	if player_data.is_empty():
		push_warning("WorldSaveCoordinator: player file missing/corrupt")
		return false
	var global_data := _read_json_with_backup(SLOT_PATH + "global_world.json")
	WorldTimeService.from_dict(global_data.get("world_time", {}))
	_id_counters = global_data.get("id_counters", {}).duplicate(true)
	RelationshipService.from_dict(_read_json_with_backup(SLOT_PATH + "relationships.json"))
	QuestManager.from_dict(_read_json_with_backup(SLOT_PATH + "quests.json"))
	if _world_flags != null:
		_world_flags.from_dict(_read_json_with_backup(SLOT_PATH + "world_flags.json"))
	var region_chunks_map: Dictionary = manifest.get("region_chunks", {})
	_region_chunk_map = region_chunks_map.duplicate(true)
	var region_id := StringName(str(manifest.get("current_region_id", "base:town")))
	if _session != null and _session.has_method("restore_global_world_data"):
		_session.call("restore_global_world_data", global_data)
	if _session != null and _session.has_method("restore_player_data"):
		_session.call("restore_player_data", player_data)
	if _region_service != null:
		_load_all_region_chunks(region_chunks_map)
		var ctx := RegionTransitionContext.new()
		ctx.restore_saved_transform = true
		_region_service.enter_region(region_id, &"", ctx)
	var companions := _read_json_with_backup(SLOT_PATH + "companions.json")
	if _session != null and _session.has_method("restore_companions"):
		_session.call("restore_companions", companions)
	# Apply exact player transform after region load when continuing.
	if _session != null and _session.has_method("apply_saved_player_transform"):
		_session.call("apply_saved_player_transform", player_data)
	return true


func _load_all_region_chunks(region_chunks_map: Dictionary) -> void:
	if not region_chunks_map.is_empty():
		for region_key in region_chunks_map.keys():
			var fname := str(region_chunks_map[region_key])
			var chunk := _read_region_chunk_file(fname, StringName(str(region_key)))
			if not chunk.is_empty():
				_region_service.set_region_chunk(StringName(str(region_key)), chunk)
		return
	for file_name in _list_region_files():
		var region_id := RegionIdUtil.from_chunk_filename(file_name)
		var chunk2 := _read_region_chunk_file(file_name, region_id)
		if not chunk2.is_empty():
			_region_service.set_region_chunk(region_id, chunk2)


func _read_region_chunk_file(file_name: String, region_id: StringName) -> Dictionary:
	var path := SLOT_PATH + "regions/" + file_name
	var chunk := _read_json_with_backup(path)
	if chunk.is_empty():
		push_warning("WorldSaveCoordinator: region chunk corrupt/missing for %s; using defaults" % String(region_id))
		return {}
	# Sanitize entity snapshots.
	var entities: Dictionary = chunk.get("entities", {})
	var cleaned: Dictionary = {}
	for key in entities.keys():
		var entry: Variant = entities[key]
		if typeof(entry) != TYPE_DICTIONARY:
			push_warning("WorldSaveCoordinator: skipped corrupt entity %s" % str(key))
			continue
		var data: Dictionary = entry
		if not data.has("persistent_id"):
			push_warning("WorldSaveCoordinator: skipped corrupt entity %s" % str(key))
			continue
		cleaned[str(key)] = data
	chunk["entities"] = cleaned
	return chunk


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
	var regions: Dictionary = raw.get("regions", {})
	var discovered: Array = regions.get("discovered", ["town"])
	var discovered_norm: Array = []
	for d in discovered:
		discovered_norm.append(String(RegionIdUtil.normalize(StringName(str(d)))))
	_write_json(SLOT_PATH + "global_world.json", {
		"world_time": raw.get("world", {}),
		"discovered_regions": discovered_norm,
		"id_counters": {},
	})
	_write_json(SLOT_PATH + "relationships.json", raw.get("relationships", {}))
	_write_json(SLOT_PATH + "quests.json", raw.get("quests", {}))
	_write_json(SLOT_PATH + "world_flags.json", {})
	_write_json(SLOT_PATH + "companions.json", {
		"pets": raw.get("pets", {}),
		"mounts": raw.get("mounts", {}),
		"unlocked_pet_ids": [],
		"unlocked_mount_ids": [],
	})
	_migrate_v3_entities_to_chunks(raw)
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
		_append_entity_to_chunk(region, SaveV3MigrationMapping.npc_persistent_id(str(npc_key)), StringName(str(npc_key)), npc_data)
	for iname in interactables.keys():
		var idata: Dictionary = interactables[iname]
		var region2 := RegionIdUtil.normalize(mapping.get(iname, &"base:town"))
		var pid := SaveV3MigrationMapping.interactable_persistent_id(str(iname), region2)
		_append_entity_to_chunk(region2, pid, &"", idata)


func _append_entity_to_chunk(region_id: StringName, persistent_id: StringName, definition_id: StringName, data: Dictionary) -> void:
	var fname := SLOT_PATH + "regions/%s.json" % RegionIdUtil.to_chunk_filename(region_id)
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
	_region_chunk_map[String(region_id)] = RegionIdUtil.to_chunk_filename(region_id) + ".json"


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
		"region_chunks": _region_chunk_map.duplicate(true),
		"checksum_version": 1,
	})


func _write_manifest() -> void:
	if _session == null or _region_service == null:
		return
	var world_time := WorldTimeService.to_dict()
	_write_json(SLOT_PATH + "manifest.json", {
		"save_version": WORLD_SAVE_VERSION,
		"game_version": "0.7.0",
		"slot_id": "slot_01",
		"created_at": int(Time.get_unix_time_from_system()),
		"updated_at": int(Time.get_unix_time_from_system()),
		"player_name": GameManager.player_name,
		"current_region_id": String(_region_service.get_current_region_id()),
		"current_spawn_id": "spawn",
		"day": int(world_time.get("day", 1)),
		"hour": int(world_time.get("hour", 8)),
		"minute": int(world_time.get("minute", 0)),
		"play_time_seconds": 0,
		"content_packs": {},
		"region_chunks": _region_chunk_map.duplicate(true),
		"checksum_version": 1,
	})


func _save_named_section(section_id: StringName) -> bool:
	match String(section_id):
		"profile":
			return _write_json(SLOT_PATH + "profile.json", {"player_name": GameManager.player_name})
		"player":
			if _session == null:
				return false
			return _write_json(SLOT_PATH + "player.json", _session.call("capture_player_data"))
		"global_world":
			var discovered: Array = []
			if _session != null and _session.has_method("capture_global_world_data"):
				var g: Dictionary = _session.call("capture_global_world_data")
				g["id_counters"] = _id_counters.duplicate(true)
				return _write_json(SLOT_PATH + "global_world.json", g)
			if _session != null:
				discovered = _session.get("discovered_regions")
			return _write_json(SLOT_PATH + "global_world.json", {
				"world_time": WorldTimeService.to_dict(),
				"discovered_regions": discovered,
				"current_region_id": String(_region_service.get_current_region_id()) if _region_service else "",
				"id_counters": _id_counters.duplicate(true),
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
			return true


func _save_region_chunk(region_id: StringName) -> bool:
	if _region_service == null:
		return false
	var chunk: Dictionary = _region_service.get_region_chunk(region_id)
	if chunk.is_empty() and RegionIdUtil.normalize(region_id) == _region_service.get_current_region_id():
		chunk = _region_service.capture_current_region_chunk()
		_region_service.set_region_chunk(region_id, chunk)
	if chunk.is_empty():
		# Still write an empty-but-valid chunk so mapping stays consistent.
		chunk = {
			"region_id": String(RegionIdUtil.normalize(region_id)),
			"region_state_version": 1,
			"entities": {},
			"destroyed_entities": [],
			"spawn_states": {},
			"custom_state": {},
		}
	var fname := RegionIdUtil.to_chunk_filename(region_id) + ".json"
	_region_chunk_map[String(RegionIdUtil.normalize(region_id))] = fname
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SLOT_PATH + "regions"))
	return _write_json(SLOT_PATH + "regions/" + fname, chunk)


func _get_known_regions() -> Array[StringName]:
	var result: Array[StringName] = []
	var seen: Dictionary = {}
	for def in ResourceRegistry.get_all_regions():
		if def == null:
			continue
		var id := RegionIdUtil.normalize(def.id)
		if seen.has(id):
			continue
		seen[id] = true
		result.append(id)
	if _session != null:
		for d in _session.get("discovered_regions"):
			var rid := RegionIdUtil.normalize(StringName(str(d)))
			if not seen.has(rid):
				seen[rid] = true
				result.append(rid)
	for key in _region_chunk_map.keys():
		var rid2 := RegionIdUtil.normalize(StringName(str(key)))
		if not seen.has(rid2):
			seen[rid2] = true
			result.append(rid2)
	return result


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
	# Keep .bak for corruption recovery of critical files.
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


func _read_json_with_backup(path: String) -> Dictionary:
	var data := _read_json(path)
	if not data.is_empty():
		return data
	var bak := ProjectSettings.globalize_path(path) + ".bak"
	if FileAccess.file_exists(bak):
		var file := FileAccess.open(bak, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if typeof(parsed) == TYPE_DICTIONARY:
				push_warning("WorldSaveCoordinator: recovered %s from backup" % path)
				return parsed
	return {}


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
