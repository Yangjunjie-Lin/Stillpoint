extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)

	world.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree)
	var herb := WorldTestHelper.find_pickup(world)
	if herb == null:
		push_error("HerbPickup not found")
		world.free()
		return false
	herb.interact(world.player, InteractionContext.new(world.player))

	world.transition_to(&"base:town")
	await WorldTestHelper.await_frames(tree)
	if not world.save_world_state():
		push_error("save failed")
		world.free()
		return false
	world.free()

	var chunk := _read_region_chunk(&"base:wilderness")
	var entities: Dictionary = chunk.get("entities", {})
	var entry: Variant = entities.get("base:wilderness/pickup/herb_0001", {})
	if typeof(entry) != TYPE_DICTIONARY:
		push_error("pickup missing from wilderness chunk")
		return false
	var components: Dictionary = (entry as Dictionary).get("components", {})
	var pickup_state: Dictionary = components.get("pickup", components.get("entity", {}))
	if not bool(pickup_state.get("collected", false)):
		push_error("pickup collected state not saved")
		return false
	return true


func _read_region_chunk(region_id: StringName) -> Dictionary:
	var path := "user://saves/slot_01/regions/%s.json" % RegionIdUtil.to_chunk_filename(region_id)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed
