extends SceneTree
## Captures deterministic 1280x720 previews of the two primary RPG information surfaces.

const OUTPUT_DIR := "res://artifacts/ui-previews"


func _initialize() -> void:
	call_deferred("_capture")


func _capture() -> void:
	print("UI preview: preparing viewport")
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	root.size = Vector2i(1280, 720)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var save_service: Node = root.get_node("SaveService") as Node
	var settings: Dictionary = save_service.get("settings")
	settings["ai_dialogue_enabled"] = true
	# Keep runtime classes dynamically loaded: SceneTree entry scripts compile before
	# project Autoload identifiers become available.
	var scene: PackedScene = load("res://scenes/world/world_session.tscn") as PackedScene
	var world: Node = scene.instantiate()
	root.add_child(world)
	await _frames(5)

	var ledger: Control = world.get_node("WorldUI/InventoryMenu") as Control
	# Present the real runtime control without pausing this SceneTree capture driver.
	ledger.visible = true
	ledger.call("_refresh")
	for page_index in 4:
		ledger.call("_select_page", page_index)
		await _frames(2)
		_capture_viewport(
			world.get_viewport(),
			"%s/ledger-%02d.png" % [OUTPUT_DIR, page_index + 1],
		)
	ledger.visible = false
	await _frames(2)

	var entity_repository: Node = world.get("entity_repository") as Node
	var mira: Node = entity_repository.call("get_loaded_entity", &"base:town/npc/mira") as Node
	if mira == null:
		mira = entity_repository.call("get_loaded_entity", &"base:town/npc/mira_0001") as Node
	if mira != null:
		world.call("start_dialogue", mira)
		await _frames(3)
		_capture_viewport(world.get_viewport(), "%s/dialogue-panel.png" % OUTPUT_DIR)
		var dialogue: Control = world.get_node("WorldUI/DialoguePanel") as Control
		var warden_dialogue: Resource = load("res://resources/dialogues/dungeon_warden_gate.tres")
		var start_node: Resource = warden_dialogue.call("get_node", &"start") as Resource
		dialogue.call(
			"_on_line",
			"Warden Aster",
			"This is the Warden's Threshold. I can send you only as deep as your combat training allows.",
		)
		dialogue.call("_on_choices", start_node.get("choices"))
		await _frames(3)
		_capture_viewport(world.get_viewport(), "%s/dialogue-five-choices.png" % OUTPUT_DIR)
		dialogue.call("_show_free_form")
		await _frames(3)
		_capture_viewport(world.get_viewport(), "%s/dialogue-free-form.png" % OUTPUT_DIR)
	else:
		push_error("UI preview capture could not find Mira")

	world.free()
	await _frames(2)
	quit()


func _capture_viewport(viewport: Viewport, path: String) -> void:
	var image := viewport.get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		push_error("UI preview capture failed for %s: %s" % [path, error_string(error)])
	else:
		print("UI preview captured: %s" % path)


func _frames(count: int) -> void:
	for _index in count:
		await process_frame
