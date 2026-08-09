extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var previous_settings := SaveService.settings.duplicate(true)
	SaveService.settings["ai_dialogue_enabled"] = true
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var panel := world.get_node("WorldUI/DialoguePanel") as DialogueUI
	var mira := world.entity_repository.get_loaded_entity(&"base:town/npc/mira") as NPCController
	var ok := panel != null and mira != null

	if ok:
		ok = world.start_dialogue(mira)
		await tree.process_frame
	if ok:
		panel.call("_show_free_form")
		panel.free_form_input.text = "A submitted question"
		panel.call("_submit_free_form")
		ok = panel.free_form_input.text.is_empty()

	if panel != null:
		panel.call("_cancel_free_form")
	if ok:
		ok = world.start_dialogue(mira)
		await tree.process_frame
	if ok:
		panel.call("_show_free_form")
		ok = panel.free_form_input.text.is_empty()
		panel.free_form_input.text = "A cancelled draft"
		panel.call("_cancel_free_form")
		panel.call("_show_free_form")
		ok = panel.free_form_input.text.is_empty()

	world.free()
	SaveService.settings.clear()
	SaveService.settings.merge(previous_settings, true)
	if not ok:
		push_error("Free-form dialogue input retained text after submission or cancellation")
	return ok
