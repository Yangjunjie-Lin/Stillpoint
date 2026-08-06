extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)
	var ren := WorldTestHelper.find_npc(world, "Ren")
	RelationshipService.ensure_registered(&"ren", &"neutral")
	ren.react_to_aggression(world.player, 15.0)
	var ok := RelationshipService.get_disposition(&"ren") == RelationshipComponent.Disposition.HOSTILE
	ok = ok and ren.npc_state in [NPCController.NPCState.ATTACK, NPCController.NPCState.CHASE, NPCController.NPCState.FLEE]
	world.free()
	return ok
