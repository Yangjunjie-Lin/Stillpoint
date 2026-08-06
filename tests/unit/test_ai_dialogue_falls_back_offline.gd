extends RefCounted

func run() -> bool:
	var controller := NPCConversationController.new()
	var npc := NPCController.new()
	npc.npc_definition = ResourceRegistry.get_npc(&"mira")
	var accepted := controller.ask(npc, {"request_id": "offline"})
	npc.free()
	controller.free()
	return not accepted
