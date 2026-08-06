extends RefCounted


func _mtime(path: String) -> int:
	return FileAccess.get_modified_time(path)


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)

	world.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree)
	world.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree)
	world.transition_to(&"base:town")
	await WorldTestHelper.await_frames(tree)
	world.save_coordinator.save_all()
	await WorldTestHelper.await_frames(tree)

	var wild_path := ProjectSettings.globalize_path("user://saves/slot_01/regions/base_wilderness.json")
	var town_path := ProjectSettings.globalize_path("user://saves/slot_01/regions/base_town.json")
	var wild_before := _mtime(wild_path)

	var chest := _find_chest(world)
	if chest != null:
		chest.interact(world.player, InteractionContext.new(world.player))
	world.save_coordinator.mark_region_dirty(&"base:town")
	world.save_coordinator.save_dirty_sections()
	await WorldTestHelper.await_frames(tree)

	var wild_after := _mtime(wild_path)
	var town_after := _mtime(town_path)
	if wild_before > 0 and wild_after != wild_before:
		push_error("clean wilderness chunk was rewritten")
		world.free()
		return false
	if town_after <= 0:
		push_error("town chunk missing after dirty save")
		world.free()
		return false

	world.free()
	return true


func _find_chest(world: WorldSession) -> ChestInteractable3D:
	var root := world.region_service.get_current_region_root()
	if root == null:
		return null
	return root.find_child("Chest", true, false) as ChestInteractable3D
