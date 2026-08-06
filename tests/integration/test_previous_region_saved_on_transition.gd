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
	world.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree)
	if not world.save_world_state():
		push_error("save failed")
		world.free()
		return false
	world.free()

	var chunk := _read_region_chunk(&"base:town")
	var entities: Dictionary = chunk.get("entities", {})
	var entry: Variant = entities.get(String(CHEST_PID), entities.get("base:town/interactable/chest_0001", {}))
	if typeof(entry) != TYPE_DICTIONARY:
		push_error("chest entity missing from town chunk")
		return false
	var components: Dictionary = (entry as Dictionary).get("components", {})
	var chest_state: Dictionary = components.get("chest", components.get("entity", {}))
	if not bool(chest_state.get("opened", false)):
		push_error("chest opened state not saved in town chunk")
		return false
	return true


func _find_chest(world: WorldSession) -> ChestInteractable3D:
	var root := world.region_service.get_current_region_root()
	if root == null:
		return null
	return root.find_child("Chest", true, false) as ChestInteractable3D


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
