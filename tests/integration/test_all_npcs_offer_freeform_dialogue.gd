extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var previous_settings := SaveService.settings.duplicate(true)
	SaveService.settings["ai_dialogue_enabled"] = true
	QuestManager.reset_all()
	RelationshipService.reset_all()
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var dialogue_ui := world.get_node("WorldUI/DialoguePanel") as DialogueUI
	var ok := true

	for npc_name in ["Mira", "Ren"]:
		var npc := WorldTestHelper.find_npc(world, npc_name)
		ok = world.start_dialogue(npc) and ok
		await tree.process_frame
		ok = _has_button(dialogue_ui, "Ask something else...") and ok
		world.cancel_active_dialogue()
		await tree.process_frame

	world.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree, 4)
	for persistent_id in [
		&"base:dungeon/npc/bandit_0001",
		&"base:dungeon/npc/bandit_0002",
	]:
		var bandit := world.entity_repository.get_loaded_entity(persistent_id) as NPCController
		ok = bandit != null and ok
		if bandit == null:
			continue
		ok = bandit.get_node_or_null("NPCInteractable") is NPCInteractable and ok
		ok = world.start_dialogue(bandit) and ok
		await tree.process_frame
		ok = world.dialogue_coordinator.get_active_npc() == bandit and ok
		ok = _has_button(dialogue_ui, "Ask something else...") and ok
		ok = _has_button(dialogue_ui, "Leave") and ok
		world.cancel_active_dialogue()
		await tree.process_frame

	world.free()
	SaveService.settings.clear()
	SaveService.settings.merge(previous_settings, true)
	return ok


func _has_button(dialogue_ui: DialogueUI, label: String) -> bool:
	if dialogue_ui == null or not dialogue_ui.visible:
		return false
	for child in dialogue_ui.choices_container.get_children():
		if child is Button and (child as Button).text == label:
			return true
	return false
