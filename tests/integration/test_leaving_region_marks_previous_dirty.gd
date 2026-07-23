extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)

	var chest := _find_chest(world)
	if chest == null:
		push_error("Chest not found in town")
		world.free()
		return false
	chest.interact(world.player, InteractionContext.new(world.player))
	await WorldTestHelper.await_frames(tree)

	world.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree)

	var dirty := world.save_coordinator._dirty_regions
	var repo_dirty := world.entity_repository.peek_dirty_regions()
	var town_dirty := dirty.has(&"base:town") or repo_dirty.has(&"base:town")
	if not town_dirty:
		push_error("town not marked dirty after leaving region")
		world.free()
		return false

	var chunk := world.region_service.get_region_chunk(&"base:town")
	if chunk.is_empty():
		push_error("town chunk not captured on transition")
		world.free()
		return false

	world.free()
	return true


func _find_chest(world: WorldSession) -> ChestInteractable3D:
	var root := world.region_service.get_current_region_root()
	if root == null:
		return null
	return root.find_child("Chest", true, false) as ChestInteractable3D
