extends Node
## JSON persistence under user:// with atomic writes, migration, and validation.

const SAVE_VERSION: int = 2
const RUN_PATH := "user://run_save.json"
const SETTINGS_PATH := "user://settings.json"
const LEADERBOARD_PATH := "user://leaderboard.json"
const DEFAULT_MAX_AGE := 86400.0
const MAX_COORD := 1_000_000.0

var settings: Dictionary = {
	"fullscreen": true,
	"master_volume_db": 0.0,
	"music_volume_db": -6.0,
	"sfx_volume_db": -3.0,
	"show_diagnostics": false,
	"renderer_preference": "compatibility",
}

## Test-only: fail the next N atomic replace renames (tmp -> final).
var _test_fail_replace_count: int = 0


func _ready() -> void:
	load_settings()
	if DisplayServer.get_name() != "headless":
		_apply_settings()


func save_run(data: Dictionary) -> bool:
	var payload := data.duplicate(true)
	payload["version"] = SAVE_VERSION
	payload["saved_at"] = int(Time.get_unix_time_from_system())
	payload["is_game_over"] = false
	return _write_json(RUN_PATH, payload)


func has_valid_run(max_age_seconds: float = DEFAULT_MAX_AGE) -> bool:
	return inspect_run(max_age_seconds).valid


func inspect_run(max_age_seconds: float = DEFAULT_MAX_AGE) -> RunSaveSummary:
	var summary := RunSaveSummary.new()
	var raw := _read_json(RUN_PATH)
	if raw.is_empty():
		summary.reason = "missing"
		return summary

	var migrated := migrate_payload(raw)
	if bool(migrated.get("is_game_over", false)):
		summary.reason = "game_over"
		return summary

	var validation := validate_run_payload(migrated)
	if not validation.valid:
		summary.reason = String(validation.reason)
		return summary

	var payload := validation.normalized_payload
	if bool(payload.get("is_game_over", false)):
		summary.reason = "game_over"
		return summary

	var saved_at := int(payload.get("saved_at", 0))
	if Time.get_unix_time_from_system() - float(saved_at) > max_age_seconds:
		summary.reason = "expired"
		return summary

	var player: Dictionary = payload.get("player", {})
	var experience: Dictionary = player.get("experience", {})
	summary.valid = true
	summary.player_name = str(payload.get("player_name", "Player"))
	summary.level_id = StringName(str(payload.get("level_id", "prototype")))
	summary.combat_level = int(experience.get("level", 1))
	summary.score = int(player.get("combat_score", 0)) + int(player.get("survival_seconds", 0))
	summary.survival_seconds = float(player.get("survival_seconds", 0.0))
	summary.saved_at = saved_at
	return summary


func load_run(max_age_seconds: float = DEFAULT_MAX_AGE) -> Dictionary:
	var summary := inspect_run(max_age_seconds)
	if not summary.valid:
		return {}
	var migrated := migrate_payload(_read_json(RUN_PATH))
	var validation := validate_run_payload(migrated)
	if not validation.valid:
		return {}
	return validation.normalized_payload


func validate_run_payload(payload: Dictionary) -> SaveValidationResult:
	var result := SaveValidationResult.new()
	var data := payload.duplicate(true)

	var version := int(data.get("version", -1))
	if version < 0:
		result.reason = &"invalid_version"
		result.errors.append("Save version is negative")
		return result
	if version > SAVE_VERSION:
		result.reason = &"future_version"
		result.errors.append(
			"Save version %d is newer than supported %d" % [version, SAVE_VERSION]
		)
		return result

	for key in [
		"saved_at", "is_game_over", "player_name", "level_id",
		"player", "enemies", "pickups", "difficulty_scale",
		"autosave_timer", "item_timer",
	]:
		if not data.has(key):
			result.reason = &"missing_field"
			result.errors.append("Missing required field: %s" % key)
			return result

	if not _is_finite_number(data.get("saved_at")):
		result.reason = &"invalid_saved_at"
		result.errors.append("saved_at is not finite")
		return result
	if not _is_finite_number(data.get("difficulty_scale")):
		result.reason = &"invalid_difficulty"
		result.errors.append("difficulty_scale is not finite")
		return result
	if float(data.get("difficulty_scale")) < 0.0:
		result.reason = &"invalid_difficulty"
		result.errors.append("difficulty_scale is negative")
		return result
	if not _is_finite_number(data.get("autosave_timer")) or float(data.get("autosave_timer")) < 0.0:
		result.reason = &"invalid_timer"
		result.errors.append("autosave_timer invalid")
		return result
	if not _is_finite_number(data.get("item_timer")) or float(data.get("item_timer")) < 0.0:
		result.reason = &"invalid_timer"
		result.errors.append("item_timer invalid")
		return result

	var enemies: Variant = data.get("enemies")
	if not enemies is Array:
		result.reason = &"invalid_enemies"
		result.errors.append("enemies must be an Array")
		return result
	var pickups: Variant = data.get("pickups")
	if not pickups is Array:
		result.reason = &"invalid_pickups"
		result.errors.append("pickups must be an Array")
		return result

	var player: Variant = data.get("player")
	if not player is Dictionary:
		result.reason = &"invalid_player"
		result.errors.append("player must be a Dictionary")
		return result

	if not _validate_player(player as Dictionary, result):
		return result

	result.valid = true
	result.reason = &""
	result.normalized_payload = data
	return result


func migrate_payload(payload: Dictionary) -> Dictionary:
	var migrated := payload.duplicate(true)
	var version := int(migrated.get("version", 0))
	if version < 0 or version > SAVE_VERSION:
		return migrated

	while version < SAVE_VERSION:
		match version:
			0:
				migrated = _migrate_v0_to_v1(migrated)
			1:
				migrated = _migrate_v1_to_v2(migrated)
			_:
				break
		version = int(migrated.get("version", version + 1))

	migrated["version"] = version
	return migrated


func mark_game_over() -> bool:
	return _write_json(RUN_PATH, {
		"version": SAVE_VERSION,
		"saved_at": int(Time.get_unix_time_from_system()),
		"is_game_over": true,
	})


func clear_run() -> bool:
	if not FileAccess.file_exists(RUN_PATH):
		return true
	var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(RUN_PATH))
	return err == OK


func save_settings() -> bool:
	var payload := settings.duplicate(true)
	payload["version"] = SAVE_VERSION
	var ok := _write_json(SETTINGS_PATH, payload)
	_apply_settings()
	return ok


func load_settings() -> void:
	var payload := _read_json(SETTINGS_PATH)
	if payload.is_empty():
		return
	for key in settings.keys():
		if payload.has(key):
			settings[key] = payload[key]


func record_score(player_name: String, score: int) -> Array:
	var entries: Array = load_leaderboard()
	entries.append({"name": player_name.substr(0, 24), "score": maxi(0, score)})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["score"]) > int(b["score"]))
	if entries.size() > 10:
		entries = entries.slice(0, 10)
	_write_json(LEADERBOARD_PATH, {"version": SAVE_VERSION, "entries": entries})
	return entries


func load_leaderboard() -> Array:
	var payload := _read_json(LEADERBOARD_PATH)
	if payload.is_empty():
		return []
	var entries: Variant = payload.get("entries", [])
	return entries if entries is Array else []


func _migrate_v0_to_v1(payload: Dictionary) -> Dictionary:
	var migrated := payload.duplicate(true)
	migrated["version"] = 1
	migrated["is_game_over"] = bool(migrated.get("is_game_over", false))
	return migrated


func _migrate_v1_to_v2(payload: Dictionary) -> Dictionary:
	var migrated := payload.duplicate(true)
	migrated["version"] = 2
	if not migrated.has("pickups"):
		migrated["pickups"] = []
	if not migrated.has("autosave_timer"):
		migrated["autosave_timer"] = 0.0
	if not migrated.has("item_timer"):
		migrated["item_timer"] = 0.0
	return migrated


func _validate_player(player: Dictionary, result: SaveValidationResult) -> bool:
	for key in ["position", "health", "experience", "status"]:
		if not player.has(key):
			result.reason = &"invalid_player"
			result.errors.append("player missing %s" % key)
			return false

	if not _validate_position(player.get("position", {}), result):
		return false

	if not _validate_health(player.get("health", {}), result, true):
		return false

	if not _validate_experience(player.get("experience", {}), result):
		return false

	if typeof(player.get("status")) != TYPE_DICTIONARY:
		result.reason = &"invalid_player"
		result.errors.append("player.status must be Dictionary")
		return false

	for key in ["combat_score", "survival_seconds", "game_time"]:
		if not player.has(key):
			result.reason = &"invalid_player"
			result.errors.append("player missing %s" % key)
			return false
		if not _is_finite_number(player.get(key)):
			result.reason = &"invalid_player"
			result.errors.append("player.%s is not finite" % key)
			return false
		if float(player.get(key)) < 0.0 and key != "combat_score":
			result.reason = &"invalid_player"
			result.errors.append("player.%s is negative" % key)
			return false

	return true


func _validate_position(pos: Variant, result: SaveValidationResult) -> bool:
	if typeof(pos) != TYPE_DICTIONARY:
		result.reason = &"invalid_player"
		result.errors.append("player.position must be Dictionary")
		return false
	for key in ["x", "y"]:
		if not _is_finite_number(pos.get(key, NAN)):
			result.reason = &"invalid_player"
			result.errors.append("player.position.%s is not finite" % key)
			return false
		var value := float(pos.get(key))
		if absf(value) > MAX_COORD:
			result.reason = &"invalid_player"
			result.errors.append("player.position.%s out of range" % key)
			return false
	return true


func _validate_health(health: Variant, result: SaveValidationResult, require_alive: bool) -> bool:
	if typeof(health) != TYPE_DICTIONARY:
		result.reason = &"invalid_health"
		result.errors.append("health must be Dictionary")
		return false
	for key in ["max_health", "current_health", "defense"]:
		if not _is_finite_number(health.get(key, NAN)):
			result.reason = &"invalid_health"
			result.errors.append("health.%s is not finite" % key)
			return false
	var max_hp := float(health.get("max_health"))
	var current_hp := float(health.get("current_health"))
	var defense := float(health.get("defense"))
	if max_hp <= 0.0:
		result.reason = &"invalid_health"
		result.errors.append("health.max_health must be > 0")
		return false
	if current_hp < 0.0:
		result.reason = &"invalid_health"
		result.errors.append("health.current_health is negative")
		return false
	if current_hp > max_hp + 0.001:
		result.reason = &"invalid_health"
		result.errors.append("health.current_health exceeds max_health")
		return false
	if defense < 0.0:
		result.reason = &"invalid_health"
		result.errors.append("health.defense is negative")
		return false
	if require_alive and bool(health.get("death_recorded", false)):
		result.reason = &"invalid_health"
		result.errors.append("health.death_recorded must be false for run save")
		return false
	if require_alive and current_hp <= 0.0:
		result.reason = &"invalid_health"
		result.errors.append("health.current_health must be > 0 for run save")
		return false
	return true


func _validate_experience(experience: Variant, result: SaveValidationResult) -> bool:
	if typeof(experience) != TYPE_DICTIONARY:
		result.reason = &"invalid_experience"
		result.errors.append("experience must be Dictionary")
		return false
	if int(experience.get("level", 0)) < 1:
		result.reason = &"invalid_experience"
		result.errors.append("experience.level must be >= 1")
		return false
	for key in ["current_experience", "total_experience", "enemies_defeated"]:
		if int(experience.get(key, -1)) < 0:
			result.reason = &"invalid_experience"
			result.errors.append("experience.%s is negative" % key)
			return false
	if int(experience.get("experience_to_next_level", 0)) < 1:
		result.reason = &"invalid_experience"
		result.errors.append("experience.experience_to_next_level must be >= 1")
		return false
	return true


func _is_finite_number(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	return is_finite(float(value))


func _apply_settings() -> void:
	if DisplayServer.get_name() == "headless":
		_apply_audio_volumes()
		return
	if bool(settings.get("fullscreen", true)):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	_apply_audio_volumes()


func _apply_audio_volumes() -> void:
	_set_bus_volume("Master", float(settings.get("master_volume_db", 0.0)))
	_set_bus_volume("Music", float(settings.get("music_volume_db", -6.0)))
	_set_bus_volume("SFX", float(settings.get("sfx_volume_db", -3.0)))


func _set_bus_volume(bus_name: String, volume_db: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, volume_db)


func toggle_fullscreen() -> void:
	settings["fullscreen"] = not bool(settings.get("fullscreen", true))
	save_settings()


func _write_json(path: String, payload: Variant) -> bool:
	var tmp := path + ".tmp"
	var bak := path + ".bak"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_error("SaveService: cannot write %s" % tmp)
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()

	var abs_tmp := ProjectSettings.globalize_path(tmp)
	var abs_path := ProjectSettings.globalize_path(path)
	var abs_bak := ProjectSettings.globalize_path(bak)

	if FileAccess.file_exists(path):
		if FileAccess.file_exists(bak):
			DirAccess.remove_absolute(abs_bak)
		var rename_bak := _rename_absolute(abs_path, abs_bak)
		if rename_bak != OK:
			push_error("SaveService: cannot backup %s" % path)
			DirAccess.remove_absolute(abs_tmp)
			return false

	var err := _rename_absolute(abs_tmp, abs_path)
	if err != OK:
		push_error("SaveService: atomic replace failed for %s (%s)" % [path, error_string(err)])
		if FileAccess.file_exists(bak):
			_rename_absolute(abs_bak, abs_path)
		return false

	if FileAccess.file_exists(bak):
		DirAccess.remove_absolute(abs_bak)
	return true


func _rename_absolute(source: String, target: String) -> Error:
	if _test_fail_replace_count > 0:
		_test_fail_replace_count -= 1
		return ERR_CANT_CREATE
	return DirAccess.rename_absolute(source, target)


func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveService: ignoring corrupt save at %s" % path)
		return {}
	return parsed
