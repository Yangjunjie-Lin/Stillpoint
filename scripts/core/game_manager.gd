extends Node
## Cross-scene run metadata. Combat actors are not owned here.

var player_name: String = "Player"
var diagnostics_enabled: bool = false
var run_active: bool = false
var resume_requested: bool = false


func _ready() -> void:
	pass


func start_new_adventure(requested_name: String = "Traveler") -> void:
	player_name = requested_name.strip_edges().substr(0, 24)
	if player_name.is_empty():
		player_name = "Traveler"
	run_active = true
	resume_requested = false
	_clear_world_save()
	SceneRouter.go_to_world_session()


func continue_adventure() -> void:
	var has_save := false
	var coordinator := _get_save_coordinator()
	if coordinator != null:
		has_save = coordinator.has_save()
	else:
		has_save = WorldSaveService.has_world_save()
	if not has_save:
		push_warning("GameManager: no world save to continue")
		return
	run_active = true
	resume_requested = true
	SceneRouter.go_to_world_session()


func has_resumable_adventure() -> bool:
	var coordinator := _get_save_coordinator()
	if coordinator != null:
		return coordinator.has_save()
	return WorldSaveService.has_world_save()


func start_new_run(requested_name: String = "Player") -> void:
	player_name = requested_name.strip_edges().substr(0, 24)
	if player_name.is_empty():
		player_name = "Player"
	run_active = true
	resume_requested = false
	SaveService.clear_run()
	SceneRouter.go_to_gameplay()


func continue_run() -> void:
	var summary := inspect_resumable_run()
	if not summary.valid:
		push_warning("GameManager: no resumable run (%s)" % summary.reason)
		return
	player_name = summary.player_name
	run_active = true
	resume_requested = true
	SceneRouter.go_to_gameplay()


func has_resumable_run() -> bool:
	return inspect_resumable_run().valid


func inspect_resumable_run(max_age_seconds: float = SaveService.DEFAULT_MAX_AGE) -> RunSaveSummary:
	var summary := SaveService.inspect_run(max_age_seconds)
	if not summary.valid:
		return summary
	if ResourceRegistry.get_level(summary.level_id) == null:
		summary.valid = false
		summary.reason = "unknown_level"
	return summary


func return_to_menu() -> void:
	var tree := get_tree()
	if tree != null:
		var world := tree.get_first_node_in_group("world_manager") as WorldSession
		if world != null:
			world.save_world_state()
	run_active = false
	resume_requested = false
	get_tree().paused = false
	SceneRouter.go_to_main_menu()


func _get_save_coordinator() -> WorldSaveCoordinator:
	var tree := get_tree()
	if tree == null:
		return null
	var world := tree.get_first_node_in_group("world_manager")
	if world != null and world.has_node("WorldServices/WorldSaveCoordinator"):
		return world.get_node("WorldServices/WorldSaveCoordinator") as WorldSaveCoordinator
	return null


func _clear_world_save() -> void:
	var coordinator := _get_save_coordinator()
	if coordinator != null:
		coordinator.clear_save()
	else:
		_clear_save_slot_dir()
		WorldSaveService.clear_world()


func _clear_save_slot_dir() -> void:
	var path := "user://saves/slot_01/"
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path.path_join(entry)))
		entry = dir.get_next()
	dir.list_dir_end()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_fullscreen"):
		SaveService.toggle_fullscreen()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("toggle_diagnostics"):
		diagnostics_enabled = not diagnostics_enabled
		get_viewport().set_input_as_handled()
