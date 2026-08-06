extends RefCounted


func run() -> bool:
	var coordinator := WorldSaveCoordinator.new()
	var town_path := WorldSaveCoordinator.SLOT_PATH + "regions/base_town.json"
	var backup_chunk := _chunk(&"base:town", {
		"base:town/interactable/chest_0001": _snapshot(
			"base:town/interactable/chest_0001"
		),
	})
	backup_chunk["custom_state"] = {"source": "backup"}
	if not coordinator._write_json(town_path, backup_chunk):
		return _finish(false, coordinator)
	var invalid_primary := _chunk(&"base:town", {})
	invalid_primary["entities"] = []
	if not coordinator._write_json(town_path, invalid_primary):
		return _finish(false, coordinator)
	var recovered := coordinator._read_region_chunk_file("base_town.json", &"base:town")
	var ok := str(recovered.get("custom_state", {}).get("source", "")) == "backup"

	var wilderness_path := WorldSaveCoordinator.SLOT_PATH + "regions/base_wilderness.json"
	var isolated := _chunk(&"base:wilderness", {
		"bad_transform": {
			"persistent_id": "bad_transform",
			"transform": [],
			"components": {},
		},
		"bad_components": {
			"persistent_id": "bad_components",
			"transform": {},
			"components": [],
		},
		"base:wilderness/interactable/herb_0001": _snapshot(
			"base:wilderness/interactable/herb_0001"
		),
	})
	if not coordinator._write_json(wilderness_path, isolated):
		return _finish(false, coordinator)
	var wilderness_backup := ProjectSettings.globalize_path(wilderness_path + ".bak")
	if FileAccess.file_exists(wilderness_backup):
		DirAccess.remove_absolute(wilderness_backup)
	var salvaged := coordinator._read_region_chunk_file(
		"base_wilderness.json", &"base:wilderness"
	)
	var entities: Dictionary = salvaged.get("entities", {})
	ok = ok and not entities.has("bad_transform")
	ok = ok and not entities.has("bad_components")
	ok = ok and entities.has("base:wilderness/interactable/herb_0001")
	if not ok:
		push_error("Region structural backup or isolated snapshot salvage failed")
	return _finish(ok, coordinator)


func _chunk(region_id: StringName, entities: Variant) -> Dictionary:
	return {
		"region_id": String(region_id),
		"region_state_version": 1,
		"entities": entities,
		"destroyed_entities": [],
		"spawn_states": {},
		"custom_state": {},
	}


func _snapshot(persistent_id: String) -> Dictionary:
	return {
		"persistent_id": persistent_id,
		"definition_id": "",
		"region_id": persistent_id.get_slice("/", 0),
		"transform": {},
		"components": {},
	}


func _finish(ok: bool, coordinator: WorldSaveCoordinator) -> bool:
	coordinator.clear_save()
	coordinator.free()
	return ok
