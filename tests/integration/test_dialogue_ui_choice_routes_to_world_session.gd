extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)

	var mira := world.entity_repository.get_loaded_entity(&"base:town/npc/mira") as NPCController
	if mira == null:
		push_error("Mira was not loaded for dialogue UI test")
		world.free()
		return false

	world.start_dialogue(mira)
	await WorldTestHelper.await_frames(tree, 1)
	var panel := world.get_node("WorldUI/DialoguePanel") as DialogueUI
	var choices := panel.get_node("Margin/VBox/ChoicesContainer") as VBoxContainer
	if not panel.visible or choices.get_child_count() < 1:
		push_error("Dialogue UI did not present Mira's choices")
		world.free()
		return false

	var first_choice := choices.get_child(0) as Button
	first_choice.pressed.emit()
	await WorldTestHelper.await_frames(tree, 2)
	var runtime := QuestManager.get_runtime(&"demo_errand")
	var ok := runtime != null and runtime.state == QuestDefinition.QuestState.ACTIVE
	if not ok:
		push_error("Dialogue UI choice did not route through WorldSession")
	world.free()
	return ok
