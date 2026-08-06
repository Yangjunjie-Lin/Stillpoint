extends RefCounted

const TEST_QUEST := &"integration_dialogue_talk_transaction"


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var mira := WorldTestHelper.find_npc(world, "Mira")
	if mira == null:
		world.free()
		return false

	var quest := QuestDefinition.new()
	quest.id = TEST_QUEST
	var talk := ObjectiveDefinition.new()
	talk.id = &"talk_to_mira"
	talk.objective_type = ObjectiveDefinition.ObjectiveType.TALK
	talk.event_type = GameplayEventTypes.NPC_TALKED
	talk.target_definition_id = &"mira"
	talk.required_count = 1
	var gate := RemoveItemEffect.new()
	gate.item_id = &"talk_objective_gate"
	gate.required_success = true
	talk.completion_effects = [gate]
	quest.objectives = [talk]
	ResourceRegistry.register_quest(quest)

	var start_effect := StartQuestEffect.new()
	start_effect.quest_id = TEST_QUEST
	start_effect.required_success = true
	var choice := DialogueChoice.new()
	choice.text = "Accept"
	choice.effects = [start_effect]
	var node := DialogueNode.new()
	node.id = &"start"
	node.lines = PackedStringArray(["Can you help?"])
	node.choices = [choice]
	var dialogue := DialogueDefinition.new()
	dialogue.id = &"integration_dialogue_talk_transaction"
	dialogue.start_node_id = &"start"
	dialogue.nodes = [node]

	var runner := DialogueRunner.new()
	var finished := {"count": 0}
	runner.dialogue_finished.connect(func() -> void: finished["count"] += 1)
	if not runner.start(dialogue, mira, world.player, world.get_session_context()):
		world.free()
		return false
	var first := runner.choose(0)
	var runtime := QuestManager.get_runtime(TEST_QUEST)
	var ok := not first.success
	ok = ok and runtime != null
	ok = ok and runtime.state == QuestDefinition.QuestState.ACTIVE
	ok = ok and runtime.current_objective_index == 0
	ok = ok and int(runtime.objective_progress.get("talk_to_mira", 0)) == 0
	ok = ok and int(finished["count"]) == 0

	world.player.inventory.add_item(&"talk_objective_gate", 1)
	var retry := runner.choose(0)
	ok = ok and retry.success
	ok = ok and runtime.state == QuestDefinition.QuestState.COMPLETED
	ok = ok and runtime.current_objective_index == 1
	ok = ok and int(finished["count"]) == 1
	if not ok:
		push_error("dialogue NPC_TALKED transaction did not remain retryable in place")
	world.free()
	return ok
