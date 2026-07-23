extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree)

	var chest := _find_chest(world)
	if chest != null:
		chest.interact(world.player, InteractionContext.new(world.player))

	world.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree)
	var herb := WorldTestHelper.find_pickup(world)
	if herb != null:
		herb.interact(world.player, InteractionContext.new(world.player))

	world.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree)
	var bandit := world.entity_repository.get_loaded_entity(&"base:dungeon/npc/bandit_0001") as NPCController
	if bandit != null and bandit.health != null:
		bandit.health.current_health = 17.0

	if not world.save_coordinator.save_all():
		push_error("save_all failed")
		world.free()
		return false

	var town := _read_region_chunk(&"base:town")
	var wild := _read_region_chunk(&"base:wilderness")
	var dungeon := _read_region_chunk(&"base:dungeon")
	if town.is_empty() or wild.is_empty() or dungeon.is_empty():
		push_error("one or more region chunks missing after save_all")
		world.free()
		return false

	var town_entities: Dictionary = town.get("entities", {})
	var wild_entities: Dictionary = wild.get("entities", {})
	var dungeon_entities: Dictionary = dungeon.get("entities", {})

	var town_has_chest := false
	for key in town_entities.keys():
		if str(key).contains("chest"):
			town_has_chest = true
	var wild_has_pickup := wild_entities.has("base:wilderness/pickup/herb_0001")
	var dungeon_has_bandit := dungeon_entities.has("base:dungeon/npc/bandit_0001")

	if not town_has_chest or not wild_has_pickup or not dungeon_has_bandit:
		push_error("region chunks lost distinct entity content")
		world.free()
		return false

	world.free()
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
