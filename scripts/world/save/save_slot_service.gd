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


func validate_adventure_save(slot_id: StringName = DEFAULT_SLOT_ID) -> Dictionary:
	var result := _validation_result()
	var slot_path := get_slot_path(slot_id)
	var manifest_path := slot_path.path_join("manifest.json")
	var manifest_backup_path := manifest_path + ".bak"
	var manifest_read := _read_json_result(manifest_path)
	var manifest: Dictionary = {}

	if bool(manifest_read.get("valid", false)):
		manifest = manifest_read.get("data", {})
		var manifest_reason := _validate_manifest(manifest)
		if manifest_reason == &"future_version":
			return _invalid_result(result, manifest_reason, manifest)
		if manifest_reason != &"":
			manifest.clear()

	if manifest.is_empty():
		var manifest_backup := _read_json_result(manifest_backup_path)
		if bool(manifest_backup.get("valid", false)):
			var backup_data: Dictionary = manifest_backup.get("data", {})
			var backup_reason := _validate_manifest(backup_data)
			if backup_reason == &"future_version":
				return _invalid_result(result, backup_reason, backup_data)
			if backup_reason == &"":
				manifest = backup_data
				result["used_manifest_backup"] = true
				(result["warnings"] as Array).append("manifest_recovered_from_backup")

	if manifest.is_empty():
		var has_manifest_file := (
			bool(manifest_read.get("exists", false))
			or FileAccess.file_exists(manifest_backup_path)
		)
		if has_manifest_file or _slot_has_adventure_files(slot_path):
			return _invalid_result(result, &"corrupt_manifest")
		return _invalid_result(result, &"missing")

	var player_path := slot_path.path_join("player.json")
	var player_backup_path := player_path + ".bak"
	var player_read := _read_json_result(player_path)
	var player_valid := (
		bool(player_read.get("valid", false))
		and _is_valid_player_section(player_read.get("data", {}))
	)
	if not player_valid:
		var player_backup := _read_json_result(player_backup_path)
		if (
			bool(player_backup.get("valid", false))
			and _is_valid_player_section(player_backup.get("data", {}))
		):
			player_valid = true
			result["used_player_backup"] = true
			(result["warnings"] as Array).append("player_recovered_from_backup")

	if not player_valid:
		var player_exists := (
			bool(player_read.get("exists", false))
			or FileAccess.file_exists(player_backup_path)
		)
		return _invalid_result(
			result,
			&"corrupt_player" if player_exists else &"missing_player",
			manifest,
		)

	var global_path := slot_path.path_join("global_world.json")
	var global_read := _read_json_result(global_path)
	var global_valid := (
		bool(global_read.get("valid", false))
		and _is_valid_global_world_section(global_read.get("data", {}))
	)
	if not global_valid:
		var global_backup := _read_json_result(global_path + ".bak")
		if (
			bool(global_backup.get("valid", false))
			and _is_valid_global_world_section(global_backup.get("data", {}))
		):
			result["used_global_world_backup"] = true
			(result["warnings"] as Array).append("global_world_recovered_from_backup")
		else:
			result["used_global_world_defaults"] = true
			(result["warnings"] as Array).append("global_world_defaults_used")

	result.merge(_safe_manifest_summary(manifest), true)
	result["valid"] = true
	result["slot_id"] = String(slot_id)
	return result


func inspect_adventure_summary(slot_id: StringName = DEFAULT_SLOT_ID) -> Dictionary:
	var validation := validate_adventure_save(slot_id)
	if bool(validation.get("valid", false)):
		return validation
	if str(validation.get("reason", "")) != "missing":
		return validation
	# Legacy v3 fallback.
	if FileAccess.file_exists(LEGACY_PATH):
		var legacy := WorldSaveService.inspect_summary()
		if bool(legacy.get("valid", false)):
			legacy["reason"] = "legacy_v3"
			legacy["save_version"] = 3
			legacy["warnings"] = []
			legacy["used_player_backup"] = false
			legacy["used_manifest_backup"] = false
			return legacy
		# A present but unreadable v3 Adventure is still an Adventure save. Keep it
		# from being mistaken for an absent slot and falling through to Survival.
		var legacy_data := _read_json(LEGACY_PATH)
		if int(legacy_data.get("version", 0)) > WorldSaveService.WORLD_SAVE_VERSION:
			return _invalid_result(validation, &"future_version", legacy_data)
		return _invalid_result(validation, &"corrupt_manifest")
	return validation


func clear_adventure_save(slot_id: StringName = DEFAULT_SLOT_ID) -> bool:
	var slot_path := get_slot_path(slot_id)
	_remove_dir(slot_path)
	# Also clear stray tmp/bak under slot parent.
	_clear_path_if_exists(LEGACY_PATH)
	_clear_path_if_exists(LEGACY_BACKUP)
	WorldSaveService.clear_world()
	return true


func _read_json(path: String) -> Dictionary:
	var result := _read_json_result(path)
	return result.get("data", {}) if bool(result.get("valid", false)) else {}


func _validation_result() -> Dictionary:
	return {
		"valid": false,
		"reason": "",
		"warnings": [],
		"used_player_backup": false,
		"used_manifest_backup": false,
		"used_global_world_backup": false,
		"used_global_world_defaults": false,
	}


func _invalid_result(
	result: Dictionary,
	reason: StringName,
	manifest: Dictionary = {},
) -> Dictionary:
	result["valid"] = false
	result["reason"] = String(reason)
	if not manifest.is_empty():
		result.merge(_safe_manifest_summary(manifest), true)
	return result


func _read_json_result(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false, "valid": false, "data": {}}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"exists": true, "valid": false, "data": {}}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"exists": true, "valid": false, "data": {}}
	return {"exists": true, "valid": true, "data": parsed}


func _validate_manifest(manifest: Dictionary) -> StringName:
	if not manifest.has("save_version"):
		return &"corrupt_manifest"
	var raw_version: Variant = manifest.get("save_version")
	if typeof(raw_version) not in [TYPE_INT, TYPE_FLOAT]:
		return &"corrupt_manifest"
	var version_number := float(raw_version)
	if not is_finite(version_number) or version_number != floorf(version_number):
		return &"corrupt_manifest"
	var version := int(version_number)
	if version > WORLD_SAVE_VERSION:
		return &"future_version"
	if version < 1:
		return &"corrupt_manifest"
	if str(manifest.get("current_region_id", "")).strip_edges().is_empty():
		return &"corrupt_manifest"
	if typeof(manifest.get("region_chunks", null)) != TYPE_DICTIONARY:
		return &"corrupt_manifest"
	return &""


func _is_valid_player_section(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = value
	return (
		data.has("player")
		and typeof(data.get("player")) == TYPE_DICTIONARY
		and data.has("inventory")
		and typeof(data.get("inventory")) == TYPE_DICTIONARY
	)


func _is_valid_global_world_section(value: Variant) -> bool:
	if typeof(value) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = value
	if typeof(data.get("world_time", null)) != TYPE_DICTIONARY:
		return false
	if typeof(data.get("discovered_regions", null)) != TYPE_ARRAY:
		return false
	if typeof(data.get("id_counters", null)) != TYPE_DICTIONARY:
		return false
	if data.has("current_region_id") and typeof(data.get("current_region_id")) != TYPE_STRING:
		return false
	var world_time: Dictionary = data.get("world_time", {})
	for field in ["day", "hour", "minute", "time_scale"]:
		if world_time.has(field) and not _is_finite_number(world_time.get(field)):
			return false
	if world_time.has("paused") and typeof(world_time.get("paused")) != TYPE_BOOL:
		return false
	var counters: Dictionary = data.get("id_counters", {})
	for key in counters.keys():
		if str(key).strip_edges().is_empty():
			return false
		var counter: Variant = counters[key]
		if not _is_finite_number(counter):
			return false
		var counter_number := float(counter)
		if counter_number < 0.0 or counter_number != floorf(counter_number):
			return false
	if data.has("property_banking"):
		var property_value: Variant = data.get("property_banking")
		if not property_value is Dictionary:
			return false
		var property_data := property_value as Dictionary
		var property_version: Variant = property_data.get("section_version", 1)
		if not _is_finite_number(property_version):
			return false
		var version_number := float(property_version)
		if version_number < 0.0 or version_number > 2.0 or version_number != floorf(version_number):
			return false
		if int(version_number) >= 2:
			for required_money_field in [
				"home_cash_balance", "investment_principal",
				"investment_earnings", "last_interest_day",
			]:
				if not property_data.has(required_money_field):
					return false
		for money_field in [
			"wallet_balance", "bank_balance", "last_compensation",
			"last_seen_unix", "repossession_count", "offline_reclaim_seconds",
			"home_cash_balance", "investment_principal",
			"investment_earnings", "last_interest_day",
		]:
			if property_data.has(money_field):
				var amount: Variant = property_data.get(money_field)
				if (
					not _is_finite_number(amount)
					or float(amount) < 0.0
					or float(amount) != floorf(float(amount))
				):
					return false
		if property_data.has("house_status") and str(property_data.get("house_status")) not in ["owned", "repossessed"]:
			return false
		for storage_field in ["home_storage", "bank_storage"]:
			if not property_data.has(storage_field) or not _is_valid_inventory_storage(
				property_data.get(storage_field)
			):
				return false
	return true


func _is_valid_inventory_storage(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var storage := value as Dictionary
	var slots_value: Variant = storage.get("slots", null)
	if not slots_value is Array:
		return false
	var slots := slots_value as Array
	if slots.size() > 240:
		return false
	for entry_value in slots:
		if not entry_value is Dictionary:
			return false
		var entry := entry_value as Dictionary
		if typeof(entry.get("item_id", "")) not in [TYPE_STRING, TYPE_STRING_NAME]:
			return false
		var quantity: Variant = entry.get("quantity", 0)
		if (
			not _is_finite_number(quantity)
			or float(quantity) < 0.0
			or float(quantity) != floorf(float(quantity))
		):
			return false
	return true


func _is_finite_number(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	return is_finite(float(value))


func _safe_manifest_summary(manifest: Dictionary) -> Dictionary:
	var player_name := "Traveler"
	if typeof(manifest.get("player_name")) == TYPE_STRING:
		player_name = str(manifest.get("player_name")).strip_edges()
		if player_name.is_empty():
			player_name = "Traveler"
	var day := _safe_int(manifest.get("day"), 1)
	if day < 1:
		day = 1
	var hour := clampi(_safe_int(manifest.get("hour"), 8), 0, 23)
	var minute := clampi(_safe_int(manifest.get("minute"), 0), 0, 59)
	return {
		"save_version": _safe_int(manifest.get("save_version"), WORLD_SAVE_VERSION),
		"player_name": player_name,
		"region": str(manifest.get("current_region_id", "")),
		"day": day,
		"hour": hour,
		"minute": minute,
		"created_at": _safe_int(manifest.get("created_at"), 0),
		"updated_at": _safe_int(manifest.get("updated_at"), 0),
	}


func _safe_int(value: Variant, fallback: int) -> int:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return fallback
	var number := float(value)
	if not is_finite(number):
		return fallback
	return int(number)


func _slot_has_adventure_files(slot_path: String) -> bool:
	var dir := DirAccess.open(slot_path)
	if dir == null:
		return false
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry not in [".", ".."]:
			dir.list_dir_end()
			return true
		entry = dir.get_next()
	dir.list_dir_end()
	return false


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
