extends Node
## JSON persistence under user:// with atomic writes and versioned migration.

const SAVE_VERSION: int = 2
const RUN_PATH := "user://run_save.json"
const SETTINGS_PATH := "user://settings.json"
const LEADERBOARD_PATH := "user://leaderboard.json"
const DEFAULT_MAX_AGE := 86400.0

var settings: Dictionary = {
	"fullscreen": true,
	"master_volume_db": 0.0,
	"music_volume_db": -6.0,
	"sfx_volume_db": -3.0,
	"show_diagnostics": false,
	"renderer_preference": "compatibility",
}


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
	var payload := _read_json(RUN_PATH)
	if payload.is_empty():
		summary.reason = "missing"
		return summary
	payload = migrate_payload(payload)
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
	if not has_valid_run(max_age_seconds):
		return {}
	var payload := migrate_payload(_read_json(RUN_PATH))
	return payload


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


func migrate_payload(payload: Dictionary) -> Dictionary:
	var version := int(payload.get("version", 0))
	if version <= 0:
		payload = _migrate_v0_to_v1(payload)
		version = 1
	if version == 1:
		payload = _migrate_v1_to_v2(payload)
		version = 2
	payload["version"] = version
	return payload


func _migrate_v0_to_v1(payload: Dictionary) -> Dictionary:
	payload["version"] = 1
	payload["is_game_over"] = bool(payload.get("is_game_over", false))
	return payload


func _migrate_v1_to_v2(payload: Dictionary) -> Dictionary:
	payload["version"] = 2
	if not payload.has("pickups"):
		payload["pickups"] = []
	if not payload.has("autosave_timer"):
		payload["autosave_timer"] = 0.0
	if not payload.has("item_timer"):
		payload["item_timer"] = 0.0
	return payload


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
		var rename_bak := DirAccess.rename_absolute(abs_path, abs_bak)
		if rename_bak != OK:
			push_error("SaveService: cannot backup %s" % path)
			DirAccess.remove_absolute(abs_tmp)
			return false

	var err := DirAccess.rename_absolute(abs_tmp, abs_path)
	if err != OK:
		push_error("SaveService: atomic replace failed for %s (%s)" % [path, error_string(err)])
		if FileAccess.file_exists(bak):
			DirAccess.rename_absolute(abs_bak, abs_path)
		return false

	if FileAccess.file_exists(bak):
		DirAccess.remove_absolute(abs_bak)
	return true


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
