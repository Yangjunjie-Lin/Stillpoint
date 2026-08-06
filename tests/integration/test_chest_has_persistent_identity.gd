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
	var identity := chest.get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity
	if identity == null or not identity.is_valid():
		push_error("chest missing valid WorldEntityIdentity")
		world.free()
		return false
	if identity.persistent_id == &"":
		push_error("chest persistent_id empty")
		world.free()
		return false
	world.free()
	return true


func _find_chest(world: WorldSession) -> ChestInteractable3D:
	var root := world.region_service.get_current_region_root()
	if root == null:
		return null
	return root.find_child("Chest", true, false) as ChestInteractable3D
