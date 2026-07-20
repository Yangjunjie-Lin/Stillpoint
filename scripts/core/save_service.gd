extends Node
## JSON persistence under user:// with atomic writes. Never executes save contents.

const SAVE_VERSION: int = 1
const RUN_PATH := "user://run_save.json"
const SETTINGS_PATH := "user://settings.json"
const LEADERBOARD_PATH := "user://leaderboard.json"

var settings: Dictionary = {
	"fullscreen": true,
	"master_volume_db": 0.0,
	"show_diagnostics": false,
}


func _ready() -> void:
	load_settings()
	if DisplayServer.get_name() != "headless":
		_apply_settings()


func save_run(data: Dictionary) -> bool:
	var payload := data.duplicate(true)
	payload["version"] = SAVE_VERSION
	payload["saved_at"] = Time.get_unix_time_from_system()
	payload["is_game_over"] = false
	return _write_json(RUN_PATH, payload)


func load_run(max_age_seconds: float = 86400.0) -> Dictionary:
	var payload := _read_json(RUN_PATH)
	if payload.is_empty():
		return {}
	if bool(payload.get("is_game_over", false)):
		return {}
	var saved_at := float(payload.get("saved_at", 0.0))
	if Time.get_unix_time_from_system() - saved_at > max_age_seconds:
		return {}
	return payload


func mark_game_over() -> void:
	_write_json(RUN_PATH, {
		"version": SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"is_game_over": true,
	})


func clear_run() -> void:
	if FileAccess.file_exists(RUN_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUN_PATH))


func save_settings() -> bool:
	var payload := settings.duplicate(true)
	payload["version"] = SAVE_VERSION
	return _write_json(SETTINGS_PATH, payload)


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
		return
	if bool(settings.get("fullscreen", true)):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)


func toggle_fullscreen() -> void:
	settings["fullscreen"] = not bool(settings.get("fullscreen", true))
	_apply_settings()
	save_settings()


func _write_json(path: String, payload: Variant) -> bool:
	var tmp := path + ".tmp"
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		push_error("SaveService: cannot write %s" % tmp)
		return false
	file.store_string(JSON.stringify(payload, "\t"))
	file.close()
	var abs_tmp := ProjectSettings.globalize_path(tmp)
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(abs_path)
	var err := DirAccess.rename_absolute(abs_tmp, abs_path)
	if err != OK:
		push_error("SaveService: atomic replace failed for %s (%s)" % [path, error_string(err)])
		return false
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
