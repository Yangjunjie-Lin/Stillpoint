#!/usr/bin/env python3
"""Offline bootstrap helper: writes Stillpoint Godot 4.7 project skeleton files."""

from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def write(rel: str, content: str) -> None:
    path = ROOT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content.lstrip("\n"), encoding="utf-8")
    print(f"wrote {rel}")


def main() -> None:
    write(
        "project.godot",
        r'''
; Engine configuration file.
config_version=5

[application]

config/name="Stillpoint"
config/description="Hold the center. Break the swarm."
config/version="0.4.0"
run/main_scene="res://scenes/bootstrap/main.tscn"
config/features=PackedStringArray("4.7", "Forward Plus")
config/icon="res://assets/characters/player_up.png"

[autoload]

EventBus="*res://scripts/core/event_bus.gd"
GameManager="*res://scripts/core/game_manager.gd"
SceneRouter="*res://scripts/core/scene_router.gd"
SaveService="*res://scripts/core/save_service.gd"
AudioManager="*res://scripts/core/audio_manager.gd"

[display]

window/size/viewport_width=1280
window/size/viewport_height=720
window/size/mode=2
window/stretch/mode="canvas_items"
window/stretch/aspect="expand"

[input]

move_up={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":87,"key_label":0,"unicode":119,"location":0,"echo":false,"script":null)
]
}
move_down={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":83,"key_label":0,"unicode":115,"location":0,"echo":false,"script":null)
]
}
move_left={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":65,"key_label":0,"unicode":97,"location":0,"echo":false,"script":null)
]
}
move_right={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":68,"key_label":0,"unicode":100,"location":0,"echo":false,"script":null)
]
}
shoot={
"deadzone": 0.5,
"events": [Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"button_mask":0,"position":Vector2(0, 0),"global_position":Vector2(0, 0),"factor":1.0,"pressure":0.0,"tilt":Vector2(0, 0),"pen_inverted":false,"button_index":1,"canceled":false,"pressed":false,"double_click":false,"script":null)
]
}
pause={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194305,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
toggle_fullscreen={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194342,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
toggle_diagnostics={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":4194341,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}

[layer_names]

2d_physics/layer_1="world"
2d_physics/layer_2="player"
2d_physics/layer_3="enemy"
2d_physics/layer_4="projectile"
2d_physics/layer_5="pickup"
2d_physics/layer_6="hurtbox"
2d_physics/layer_7="hitbox"

[rendering]

textures/canvas_textures/default_texture_filter=0
''',
    )

    # --- Core autoload scripts ---
    write(
        "scripts/core/event_bus.gd",
        r'''
extends Node
## Global cross-system events. Prefer local signals for actor-local communication.

signal enemy_defeated(enemy_id: StringName, rewards: Dictionary)
signal player_level_changed(new_level: int)
signal player_health_changed(current: float, maximum: float)
signal player_experience_changed(current: int, to_next: int, level: int)
signal player_died(stats: Dictionary)
signal score_changed(total_score: int, combat_score: int)
signal objective_completed(objective_id: StringName)
signal level_completed(level_id: StringName)
signal run_paused(is_paused: bool)
signal notice_requested(text: String)
''',
    )

    write(
        "scripts/core/audio_manager.gd",
        r'''
extends Node
## Placeholder audio bus. SFX/music hooks for future content.

@export var master_volume_db: float = 0.0


func play_sfx(_stream: AudioStream, _volume_db: float = 0.0) -> void:
	pass


func play_music(_stream: AudioStream, _volume_db: float = 0.0) -> void:
	pass
''',
    )

    write(
        "scripts/core/scene_router.gd",
        r'''
extends Node
## Owns scene transitions through the Main CurrentScene slot.

const MAIN_MENU := "res://scenes/ui/main_menu.tscn"
const GAMEPLAY := "res://scenes/gameplay/gameplay.tscn"

var _current_scene: Node = null


func go_to_main_menu() -> void:
	change_scene(MAIN_MENU)


func go_to_gameplay() -> void:
	change_scene(GAMEPLAY)


func change_scene(scene_path: String) -> void:
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		push_error("SceneRouter: failed to load %s" % scene_path)
		return
	var root := get_tree().root.get_node_or_null("Main")
	if root == null:
		# Fallback when launched from a leaf scene in the editor.
		get_tree().change_scene_to_packed(packed)
		return
	var slot: Node = root.get_node("CurrentScene")
	for child in slot.get_children():
		child.queue_free()
	_current_scene = packed.instantiate()
	slot.add_child(_current_scene)
''',
    )

    write(
        "scripts/core/save_service.gd",
        r'''
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
''',
    )

    write(
        "scripts/core/game_manager.gd",
        r'''
extends Node
## Cross-scene run metadata. Combat actors are not owned here.

var player_name: String = "Player"
var diagnostics_enabled: bool = false
var run_active: bool = false


func start_new_run(name: String = "Player") -> void:
	player_name = name.strip_edges().substr(0, 24)
	if player_name.is_empty():
		player_name = "Player"
	run_active = true
	SaveService.clear_run()
	SceneRouter.go_to_gameplay()


func return_to_menu() -> void:
	run_active = false
	get_tree().paused = false
	SceneRouter.go_to_main_menu()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		SaveService.toggle_fullscreen()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_diagnostics"):
		diagnostics_enabled = not diagnostics_enabled
		get_viewport().set_input_as_handled()
''',
    )

    print("core scripts done")


if __name__ == "__main__":
    main()
