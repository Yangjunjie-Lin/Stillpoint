extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)

	var chest := _find_chest(world)
	if chest == null:
		push_error("Chest not found")
		world.free()
		return false
	chest.interact(world.player, InteractionContext.new(world.player))
	world.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree)
	world.transition_to(&"base:town")
	await WorldTestHelper.await_frames(tree)

	var chest2 := _find_chest(world)
	if chest2 == null or chest2.can_interact(world.player, InteractionContext.new(world.player)):
		push_error("chest state not restored on region reload")
		world.free()
		return false
	world.free()
	return true


func _find_chest(world: WorldSession) -> ChestInteractable3D:
	var root := world.region_service.get_current_region_root()
	if root == null:
		return null
	return root.find_child("Chest", true, false) as ChestInteractable3D
