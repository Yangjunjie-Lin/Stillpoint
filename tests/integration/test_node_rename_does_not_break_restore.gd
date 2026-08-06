extends RefCounted

const CHEST_PID := &"base:town/interactable/chest_0001"


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
	if not world.save_world_state():
		push_error("save failed")
		world.free()
		return false
	world.free()

	GameManager.resume_requested = true
	var world2 := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)

	var root := world2.region_service.get_current_region_root()
	var node := root.find_child("Chest", true, false)
	if node != null:
		node.name = "RenamedChestNode"
	await WorldTestHelper.await_frames(tree)

	var entity := world2.entity_repository.get_loaded_entity(CHEST_PID)
	if entity == null:
		push_error("chest not found by persistent_id after rename")
		world2.free()
		GameManager.resume_requested = false
		return false
	if entity is ChestInteractable3D and (entity as ChestInteractable3D).can_interact(
		world2.player, InteractionContext.new(world2.player)
	):
		push_error("chest state lost after node rename")
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
