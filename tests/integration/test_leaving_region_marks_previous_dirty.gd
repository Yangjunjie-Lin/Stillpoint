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

	# Capture dirty signal before transition_to autosave clears flags.
	var marked := {"town": false}
	var on_captured := func(region_id: StringName, _chunk: Dictionary) -> void:
		if region_id == &"base:town":
			marked["town"] = true
	world.region_service.region_chunk_captured.connect(on_captured)
	world.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree)

	if not bool(marked["town"]):
		push_error("town chunk was not captured when leaving region")
		world.free()
		return false

	var chunk := world.region_service.get_region_chunk(&"base:town")
	if chunk.is_empty():
		push_error("town chunk not retained after transition")
		world.free()
		return false
	var entities: Dictionary = chunk.get("entities", {})
	var chest_data: Dictionary = entities.get("base:town/interactable/chest_0001", {})
	if chest_data.is_empty():
		push_error("town chunk missing chest entity after leave")
		world.free()
		return false

	world.free()
	return true


func _find_chest(world: WorldSession) -> ChestInteractable3D:
	var root := world.region_service.get_current_region_root()
	if root == null:
		return null
	return root.find_child("Chest", true, false) as ChestInteractable3D
