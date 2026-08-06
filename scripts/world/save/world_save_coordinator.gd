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
## A failed final manifest commit is retried even after section files succeeded.
var _manifest_dirty: bool = false
var _last_save_result: String = "none"
var _entity_repository: WorldEntityRepository
var _region_service: RegionRuntimeService
var _world_flags: WorldFlagService
var _session: Node
var _id_counters: Dictionary = {}
var _npc_cognition_provider: NPCCognitionSaveProvider

## Test-only fault injection for an atomic tmp -> final rename.
var _test_fail_replace_count: int = 0
var _test_fail_replace_path_suffix: String = ""


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
	if _npc_cognition_provider == null:
		_npc_cognition_provider = NPCCognitionSaveProvider.new()
		_npc_cognition_provider.name = "NPCCognitionSaveProvider"
		add_child(_npc_cognition_provider)
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


func save_dirty_sections() -> bool:
	_absorb_repository_dirty_regions()
	if _dirty_sections.is_empty() and _dirty_regions.is_empty() and not _manifest_dirty:
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
	# The manifest is the commit record for the section/chunk generation. Never
	# publish it while any preceding write failed: doing so could advertise a new
	# chunk mapping whose file was not durably replaced.
	if not all_ok:
		_manifest_dirty = true
		_last_save_result = "partial_failure"
		return false
	var manifest_ok := _write_manifest()
	_manifest_dirty = not manifest_ok
	if not manifest_ok:
		all_ok = false
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
	if _npc_cognition_provider != null and _npc_cognition_provider.is_dirty():
		_dirty_sections[&"npc_cognition"] = true
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
	# Use the same slot validation as Main Menu so a valid manifest backup can be
	# restored, and a damaged v4 slot can never fall through to legacy migration.
	var validation := SaveSlotService.validate_adventure_save()
	if bool(validation.get("valid", false)):
		return _restore_v4(validation)
	if str(validation.get("reason", "missing")) != "missing":
		return false
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


func _restore_v4(validation: Dictionary = {}) -> bool:
	var slot_validation := validation
	if slot_validation.is_empty():
		slot_validation = SaveSlotService.validate_adventure_save()
	if not bool(slot_validation.get("valid", false)):
		return false
	var manifest := _read_validated_section(
		SLOT_PATH + "manifest.json",
		bool(slot_validation.get("used_manifest_backup", false)),
	)
	if manifest.is_empty():
		return false
	var version := int(manifest.get("save_version", 0))
	if version > WORLD_SAVE_VERSION:
		push_warning("WorldSaveCoordinator: future save version")
		return false
	GameManager.player_name = str(manifest.get("player_name", "Traveler"))
	var player_data := _read_validated_section(
		SLOT_PATH + "player.json",
		bool(slot_validation.get("used_player_backup", false)),
	)
	if player_data.is_empty():
		push_warning("WorldSaveCoordinator: player file missing/corrupt")
		return false
	var global_selection := _read_global_world_with_backup(manifest)
	var global_data: Dictionary = global_selection.get("data", {})
	WorldTimeService.from_dict(global_data.get("world_time", {}))
	_id_counters = global_data.get("id_counters", {}).duplicate(true)
	RelationshipService.from_dict(_read_json_with_backup(SLOT_PATH + "relationships.json"))
	QuestManager.from_dict(_read_json_with_backup(SLOT_PATH + "quests.json"))
	if _world_flags != null:
		_world_flags.from_dict(_read_json_with_backup(SLOT_PATH + "world_flags.json"))
	if _npc_cognition_provider != null:
		# Absence is the expected Save v4/0.7.1 compatibility path.
		_npc_cognition_provider.restore_save_data(_read_json_with_backup(SLOT_PATH + "npc_cognition.json"))
	var region_chunks_map: Dictionary = manifest.get("region_chunks", {})
	_region_chunk_map = region_chunks_map.duplicate(true)
	var region_id := StringName(str(manifest.get("current_region_id", "base:town")))
	if _session != null and _session.has_method("restore_global_world_data"):
		_session.call("restore_global_world_data", global_data)
	if _session != null and _session.has_method("restore_player_data"):
		_session.call("restore_player_data", player_data)
	if _region_service != null:
		_load_all_region_chunks(region_chunks_map)
		if bool(global_selection.get("used_defaults", false)):
			# Persist the safe defaults plus counters recovered from runtime snapshot
			# IDs on the next save, so a damaged global section cannot rewind IDs.
			mark_dirty(&"global_world")
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
				_merge_runtime_id_counters_from_chunk(chunk, StringName(str(region_key)))
				_region_service.set_region_chunk(StringName(str(region_key)), chunk)
		return
	for file_name in _list_region_files():
		var region_id := RegionIdUtil.from_chunk_filename(file_name)
		var chunk2 := _read_region_chunk_file(file_name, region_id)
		if not chunk2.is_empty():
			_merge_runtime_id_counters_from_chunk(chunk2, region_id)
			_region_service.set_region_chunk(region_id, chunk2)


func _read_region_chunk_file(file_name: String, region_id: StringName) -> Dictionary:
	var path := SLOT_PATH + "regions/" + file_name
	var primary := _read_json(path)
	var primary_container_valid := _is_valid_region_chunk_container(primary, region_id)
	if primary_container_valid and _all_entity_snapshots_valid(primary):
		return _sanitize_region_chunk(primary, region_id)

	# Structural corruption is as significant as malformed JSON. In particular,
	# an Array in `entities`, or non-Dictionary snapshot transform/components,
	# must select the last structurally valid backup when one exists.
	var backup := _read_json(path + ".bak")
	var backup_container_valid := _is_valid_region_chunk_container(backup, region_id)
	if backup_container_valid and _all_entity_snapshots_valid(backup):
		push_warning("WorldSaveCoordinator: recovered %s from structural backup" % path)
		return _sanitize_region_chunk(backup, region_id)
	if primary_container_valid:
		return _sanitize_region_chunk(primary, region_id)
	if backup_container_valid:
		push_warning("WorldSaveCoordinator: recovered salvageable %s backup" % path)
		return _sanitize_region_chunk(backup, region_id)
	push_warning(
		"WorldSaveCoordinator: region chunk corrupt/missing for %s; using defaults"
		% String(region_id)
	)
	return {}


func _is_valid_region_chunk_container(chunk: Dictionary, region_id: StringName) -> bool:
	if chunk.is_empty():
		return false
	if typeof(chunk.get("region_id", null)) != TYPE_STRING:
		return false
	var stored_region := RegionIdUtil.normalize(StringName(str(chunk.get("region_id", ""))))
	var expected_region := RegionIdUtil.normalize(region_id)
	if stored_region == &"" or (expected_region != &"" and stored_region != expected_region):
		return false
	if typeof(chunk.get("entities", null)) != TYPE_DICTIONARY:
		return false
	if chunk.has("region_state_version") and not _is_finite_number(
		chunk.get("region_state_version")
	):
		return false
	if chunk.has("destroyed_entities") and typeof(chunk.get("destroyed_entities")) != TYPE_ARRAY:
		return false
	if chunk.has("spawn_states") and typeof(chunk.get("spawn_states")) != TYPE_DICTIONARY:
		return false
	if chunk.has("custom_state") and typeof(chunk.get("custom_state")) != TYPE_DICTIONARY:
		return false
	if chunk.has("last_simulated_time") and typeof(chunk.get("last_simulated_time")) != TYPE_DICTIONARY:
		return false
	return true


func _all_entity_snapshots_valid(chunk: Dictionary) -> bool:
	var entities: Dictionary = chunk.get("entities", {})
	for entry in entities.values():
		if not _is_valid_entity_snapshot(entry):
			return false
	return true


func _is_valid_entity_snapshot(entry: Variant) -> bool:
	if typeof(entry) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = entry
	if typeof(data.get("persistent_id", null)) != TYPE_STRING:
		return false
	if str(data.get("persistent_id", "")).strip_edges().is_empty():
		return false
	for string_field in ["definition_id", "region_id", "pending_spawn_id", "entity_category"]:
		if data.has(string_field) and typeof(data.get(string_field)) != TYPE_STRING:
			return false
	if data.has("state_version") and not _is_finite_number(data.get("state_version")):
		return false
	if data.has("transform"):
		if typeof(data.get("transform")) != TYPE_DICTIONARY:
			return false
		var transform: Dictionary = data.get("transform", {})
		for transform_field in ["position", "rotation"]:
			if transform.has(transform_field):
				if typeof(transform.get(transform_field)) != TYPE_DICTIONARY:
					return false
				var vector_data: Dictionary = transform.get(transform_field, {})
				for axis in ["x", "y", "z"]:
					if vector_data.has(axis) and not _is_finite_number(vector_data.get(axis)):
						return false
	if data.has("components") and typeof(data.get("components")) != TYPE_DICTIONARY:
		return false
	if data.has("tags") and typeof(data.get("tags")) != TYPE_ARRAY:
		return false
	for bool_field in ["destroyed", "runtime_spawned"]:
		if data.has(bool_field) and typeof(data.get(bool_field)) != TYPE_BOOL:
			return false
	return true


func _sanitize_region_chunk(chunk: Dictionary, region_id: StringName) -> Dictionary:
	var sanitized := chunk.duplicate(true)
	var entities: Dictionary = chunk.get("entities", {})
	var cleaned: Dictionary = {}
	for key in entities.keys():
		var entry: Variant = entities[key]
		if not _is_valid_entity_snapshot(entry):
			push_warning("WorldSaveCoordinator: skipped corrupt entity %s" % str(key))
			continue
		cleaned[str(key)] = (entry as Dictionary).duplicate(true)
	sanitized["region_id"] = String(RegionIdUtil.normalize(region_id))
	sanitized["region_state_version"] = int(sanitized.get("region_state_version", 1))
	sanitized["entities"] = cleaned
	if not sanitized.has("destroyed_entities"):
		sanitized["destroyed_entities"] = []
	if not sanitized.has("spawn_states"):
		sanitized["spawn_states"] = {}
	if not sanitized.has("custom_state"):
		sanitized["custom_state"] = {}
	return sanitized


func _merge_runtime_id_counters_from_chunk(
	chunk: Dictionary,
	fallback_region_id: StringName,
) -> void:
	var entities: Dictionary = chunk.get("entities", {})
	for entry in entities.values():
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var snapshot: Dictionary = entry
		if not bool(snapshot.get("runtime_spawned", false)):
			continue
		var persistent_id := str(snapshot.get("persistent_id", ""))
		var parts := persistent_id.split("/", false)
		if parts.size() < 3:
			continue
		var counter_text := parts[parts.size() - 1]
		if not counter_text.is_valid_int():
			continue
		var counter := int(counter_text)
		if counter < 1:
			continue
		var category := StringName(parts[parts.size() - 2])
		var id_region := RegionIdUtil.normalize(StringName(parts[0]))
		if id_region == &"":
			id_region = RegionIdUtil.normalize(
				StringName(str(snapshot.get("region_id", fallback_region_id)))
			)
		if id_region == &"" or category == &"":
			continue
		var key := "%s:%s" % [String(id_region), String(category)]
		if counter > int(_id_counters.get(key, 0)):
			_id_counters[key] = counter
			mark_dirty(&"global_world")


func _migrate_v3_to_v4() -> bool:
	var raw := _read_json(LEGACY_PATH)
	if raw.is_empty():
		return false
	_remove_dir(SLOT_PATH)
	_region_chunk_map.clear()
	var mkdir_error := DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(SLOT_PATH + "regions")
	)
	if mkdir_error != OK:
		return _abort_v3_migration("cannot create Save v4 directories")
	if not _write_json(SLOT_PATH + "profile.json", raw.get("profile", {})):
		return _abort_v3_migration("profile section write failed")
	if not _write_json(SLOT_PATH + "player.json", {
		"player": raw.get("player", {}),
		"inventory": raw.get("inventory", {}),
	}):
		return _abort_v3_migration("player section write failed")
	var regions: Dictionary = raw.get("regions", {})
	var discovered: Array = regions.get("discovered", ["town"])
	var discovered_norm: Array = []
	for d in discovered:
		discovered_norm.append(String(RegionIdUtil.normalize(StringName(str(d)))))
	if not _write_json(SLOT_PATH + "global_world.json", {
		"world_time": raw.get("world", {}),
		"discovered_regions": discovered_norm,
		"id_counters": {},
	}):
		return _abort_v3_migration("global_world section write failed")
	if not _write_json(SLOT_PATH + "relationships.json", raw.get("relationships", {})):
		return _abort_v3_migration("relationships section write failed")
	if not _write_json(SLOT_PATH + "quests.json", raw.get("quests", {})):
		return _abort_v3_migration("quests section write failed")
	if not _write_json(SLOT_PATH + "world_flags.json", {}):
		return _abort_v3_migration("world_flags section write failed")
	if not _write_json(SLOT_PATH + "companions.json", {
		"pets": raw.get("pets", {}),
		"mounts": raw.get("mounts", {}),
		"unlocked_pet_ids": [],
		"unlocked_mount_ids": [],
	}):
		return _abort_v3_migration("companions section write failed")
	if not _migrate_v3_entities_to_chunks(raw):
		return _abort_v3_migration("region chunk write failed")
	var current := RegionIdUtil.normalize(StringName(str(regions.get("current", "town"))))
	if not _write_manifest_data(current, &"spawn", raw):
		return _abort_v3_migration("manifest write failed")
	var global_legacy := ProjectSettings.globalize_path(LEGACY_PATH)
	var backup := ProjectSettings.globalize_path(LEGACY_BACKUP)
	if FileAccess.file_exists(LEGACY_PATH):
		if FileAccess.file_exists(LEGACY_BACKUP):
			var remove_error := DirAccess.remove_absolute(backup)
			if remove_error != OK:
				push_error(
					"WorldSaveCoordinator: cannot replace legacy migration backup (%s)"
					% error_string(remove_error)
				)
				return false
		var archive_error := DirAccess.rename_absolute(global_legacy, backup)
		if archive_error != OK:
			push_error(
				"WorldSaveCoordinator: cannot archive migrated legacy save (%s)"
				% error_string(archive_error)
			)
			return false
	return _restore_v4()


func _abort_v3_migration(reason: String) -> bool:
	push_error("WorldSaveCoordinator: v3 migration aborted: %s" % reason)
	_remove_dir(SLOT_PATH)
	_region_chunk_map.clear()
	_manifest_dirty = false
	return false


func _migrate_v3_entities_to_chunks(raw: Dictionary) -> bool:
	var npcs: Dictionary = raw.get("npcs", {})
	var interactables: Dictionary = raw.get("interactables", {})
	var mapping := SaveV3MigrationMapping.INTERACTABLE_REGION_MAP
	for npc_key in npcs.keys():
		var npc_data: Dictionary = npcs[npc_key]
		var region := RegionIdUtil.normalize(StringName(str(npc_data.get("region_id", "base:town"))))
		var npc_components := SaveV3MigrationMapping.migrate_legacy_npc_state(npc_data)
		if not _append_entity_to_chunk(
			region,
			SaveV3MigrationMapping.npc_persistent_id(str(npc_key)),
			StringName(str(npc_key)),
			npc_components,
		):
			return false
	for iname in interactables.keys():
		var idata: Dictionary = interactables[iname]
		var region2 := RegionIdUtil.normalize(mapping.get(iname, &"base:town"))
		var pid := SaveV3MigrationMapping.interactable_persistent_id(str(iname), region2)
		var interactable_components := SaveV3MigrationMapping.migrate_legacy_interactable_state(
			str(iname), idata,
		)
		if not _append_entity_to_chunk(region2, pid, &"", interactable_components):
			return false
	return true


func _append_entity_to_chunk(
	region_id: StringName,
	persistent_id: StringName,
	definition_id: StringName,
	components: Dictionary,
) -> bool:
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
		"components": components.duplicate(true),
	}
	chunk["entities"] = entities
	if not _write_json(fname, chunk):
		return false
	_region_chunk_map[String(region_id)] = RegionIdUtil.to_chunk_filename(region_id) + ".json"
	return true


func _write_manifest_data(
	region_id: StringName,
	spawn_id: StringName,
	raw: Dictionary = {},
) -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SLOT_PATH))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SLOT_PATH + "regions/"))
	var profile: Dictionary = raw.get("profile", {}) if not raw.is_empty() else {}
	var world: Dictionary = raw.get("world", {}) if not raw.is_empty() else WorldTimeService.to_dict()
	return _write_json(SLOT_PATH + "manifest.json", {
		"save_version": WORLD_SAVE_VERSION,
		"game_version": "0.8.0",
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


func _write_manifest() -> bool:
	if _session == null or _region_service == null:
		return true
	var world_time := WorldTimeService.to_dict()
	return _write_json(SLOT_PATH + "manifest.json", {
		"save_version": WORLD_SAVE_VERSION,
		"game_version": "0.8.0",
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
		"npc_cognition":
			if _npc_cognition_provider == null:
				return true
			var cognition_ok := _write_json(
				SLOT_PATH + "npc_cognition.json",
				_npc_cognition_provider.capture_save_data(),
			)
			if cognition_ok:
				_npc_cognition_provider.clear_dirty()
			return cognition_ok
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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SLOT_PATH + "regions"))
	if not _write_json(SLOT_PATH + "regions/" + fname, chunk):
		return false
	# Only a successfully replaced chunk is eligible for the next manifest.
	_region_chunk_map[String(RegionIdUtil.normalize(region_id))] = fname
	return true


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
		var backup_error := _rename_absolute(global_path, bak_path)
		if backup_error != OK:
			DirAccess.remove_absolute(tmp_path)
			push_error(
				"WorldSaveCoordinator: cannot backup %s (%s)"
				% [path, error_string(backup_error)]
			)
			return false
	var replace_error := _rename_absolute(tmp_path, global_path)
	if replace_error != OK:
		# A failed atomic replace must never leave a stale tmp that can be
		# mistaken for pending save data on a later run.
		if FileAccess.file_exists(tmp_path):
			DirAccess.remove_absolute(tmp_path)
		if FileAccess.file_exists(bak_path):
			var restore_error := _rename_absolute(bak_path, global_path)
			if restore_error != OK:
				push_error(
					"WorldSaveCoordinator: cannot restore backup for %s (%s)"
					% [path, error_string(restore_error)]
				)
		push_error(
			"WorldSaveCoordinator: atomic replace failed for %s (%s)"
			% [path, error_string(replace_error)]
		)
		return false
	# Keep .bak for corruption recovery of critical files.
	return true


func _rename_absolute(source: String, target: String) -> Error:
	var normalized_target := target.replace("\\", "/")
	var matches_target := (
		_test_fail_replace_path_suffix.is_empty()
		or normalized_target.ends_with(_test_fail_replace_path_suffix)
	)
	if (
		_test_fail_replace_count > 0
		and source.ends_with(".tmp")
		and matches_target
	):
		_test_fail_replace_count -= 1
		return ERR_CANT_CREATE
	return DirAccess.rename_absolute(source, target)


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


func _read_global_world_with_backup(manifest: Dictionary) -> Dictionary:
	var path := SLOT_PATH + "global_world.json"
	var primary := _read_json(path)
	if SaveSlotService._is_valid_global_world_section(primary):
		return {"data": primary, "used_backup": false, "used_defaults": false}
	var backup := _read_json(path + ".bak")
	if SaveSlotService._is_valid_global_world_section(backup):
		push_warning("WorldSaveCoordinator: recovered %s from structural backup" % path)
		return {"data": backup, "used_backup": true, "used_defaults": false}
	push_warning("WorldSaveCoordinator: %s invalid; using warned safe defaults" % path)
	var current_region := RegionIdUtil.normalize(
		StringName(str(manifest.get("current_region_id", "base:town")))
	)
	if current_region == &"":
		current_region = &"base:town"
	return {
		"data": {
			"world_time": {
				"day": _safe_int_value(manifest.get("day"), 1),
				"hour": _safe_int_value(manifest.get("hour"), 8),
				"minute": _safe_int_value(manifest.get("minute"), 0),
				"paused": false,
				"time_scale": 1.0,
			},
			"discovered_regions": [String(current_region)],
			"current_region_id": String(current_region),
			"id_counters": {},
		},
		"used_backup": false,
		"used_defaults": true,
	}


func _safe_int_value(value: Variant, fallback: int) -> int:
	if not _is_finite_number(value):
		return fallback
	return int(value)


func _is_finite_number(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	return is_finite(float(value))


func _read_validated_section(path: String, use_backup: bool) -> Dictionary:
	if not use_backup:
		return _read_json(path)
	var backup_path := path + ".bak"
	var data := _read_json(backup_path)
	if not data.is_empty():
		push_warning("WorldSaveCoordinator: recovered %s from validated backup" % path)
	return data


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
