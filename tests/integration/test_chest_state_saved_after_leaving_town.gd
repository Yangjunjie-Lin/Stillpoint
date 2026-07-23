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
	world.save_world_state()
	world.free()

	GameManager.resume_requested = true
	var world2 := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	world2.transition_to(&"base:town")
	await WorldTestHelper.await_frames(tree)

	var chest2 := _find_chest(world2)
	if chest2 == null:
		push_error("Chest missing after re-enter town")
		world2.free()
		GameManager.resume_requested = false
		return false
	if chest2.can_interact(world2.player, InteractionContext.new(world2.player)):
		push_error("chest should remain opened after leaving town")
		world2.free()
		GameManager.resume_requested = false
		return false

	world2.free()
	GameManager.resume_requested = false
	return true


func _find_chest(world: WorldSession) -> ChestInteractable3D:
	var root := world.region_service.get_current_region_root()
	if root == null:
		return null
	return root.find_child("Chest", true, false) as ChestInteractable3D
