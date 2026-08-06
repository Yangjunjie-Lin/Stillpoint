extends RefCounted


func run() -> bool:
	var invalid_dialogue := DialogueDefinition.new()
	invalid_dialogue.id = &"unit_invalid_dialogue_start"
	invalid_dialogue.start_node_id = &"missing"
	var npc_definition := NPCDefinition.new()
	npc_definition.id = &"unit_dialogue_start_npc"
	npc_definition.default_dialogue = invalid_dialogue
	var npc := NPCController.new()
	npc.character_id = npc_definition.id
	npc.npc_definition = npc_definition
	npc.npc_state = NPCController.NPCState.WANDER
	var player := PlayerController3D.new()
	player.set_input_enabled(true)
	RelationshipService.ensure_registered(npc.character_id, &"neutral")

	var coordinator := DialogueCoordinator.new()
	coordinator.setup(WorldSessionContext.new())
	var started := {"count": 0}
	coordinator.dialogue_started.connect(
		func(_npc: NPCController) -> void: started["count"] += 1,
	)
	var result := coordinator.start_dialogue(npc, player)
	var ok := not result
	ok = ok and player.state.input_enabled
	ok = ok and npc.npc_state == NPCController.NPCState.WANDER
	ok = ok and int(started["count"]) == 0
	if not ok:
		push_error("failed DialogueRunner.start left player input or NPC state captured")
	coordinator.free()
	npc.free()
	player.free()
	return ok
