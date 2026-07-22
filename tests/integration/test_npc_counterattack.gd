extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var packed: PackedScene = load("res://scenes/world/vertical_slice.tscn") as PackedScene
	var world := packed.instantiate() as WorldManager
	tree.root.add_child(world)
	await tree.physics_frame
	var ren := world.actors_root.get_node("Ren") as NPCController
	RelationshipService.ensure_registered(&"ren", &"neutral")
	ren.react_to_aggression(world.player, 15.0)
	var ok := RelationshipService.get_disposition(&"ren") == RelationshipComponent.Disposition.HOSTILE
	ok = ok and ren.npc_state in [NPCController.NPCState.ATTACK, NPCController.NPCState.CHASE, NPCController.NPCState.FLEE]
	world.free()
	return ok
