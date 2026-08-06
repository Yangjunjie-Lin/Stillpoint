extends RefCounted

func run() -> bool:
	var controller := NPCConversationController.new()
	var npc := NPCController.new()
	npc.npc_definition = ResourceRegistry.get_npc(&"mira")
	npc.npc_state = NPCController.NPCState.WANDER
	controller.ask(npc, {"request_id": "timeout"})
	var restored := npc.npc_state == NPCController.NPCState.WANDER
	npc.free()
	controller.free()
	return restored
