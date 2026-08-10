extends RefCounted


const BANDIT_A := &"base:dungeon/npc/bandit_0001"
const BANDIT_B := &"base:dungeon/npc/bandit_0002"


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	world.transition_to(&"base:dungeon")
	await WorldTestHelper.await_frames(tree, 3)
	var player := world.player
	var ok := player != null and player.experience != null
	var starting_damage := player.combat.damage_bonus
	var starting_max_health := player.health.max_health
	var collected_items: Array[StringName] = []

	for enemy_id in [BANDIT_A, BANDIT_B]:
		var bandit := world.entity_repository.get_loaded_entity(enemy_id) as NPCController
		ok = ok and bandit != null
		if bandit == null:
			continue
		bandit.set_physics_process(false)
		bandit.health.invulnerability_duration = 0.0
		bandit.receive_damage(10_000.0, player)
		await WorldTestHelper.await_frames(tree, 2)
		var drop := _find_drop(world, enemy_id)
		ok = ok and drop != null and drop.is_active_drop()
		if drop != null and drop.is_active_drop():
			var item_id := drop.get_item_id()
			var definition := ResourceRegistry.get_item(item_id)
			ok = ok and definition != null
			ok = ok and definition.equip_slot != ItemDefinition.EquipSlot.NONE
			var before := player.inventory.count_item(item_id)
			drop.interact(player, InteractionContext.new(player))
			ok = ok and drop.is_collected()
			ok = ok and player.inventory.count_item(item_id) == before + 1
			collected_items.append(item_id)

	ok = ok and player.experience.enemies_defeated == 2
	ok = ok and player.experience.total_experience == 120
	ok = ok and player.experience.level == 2
	ok = ok and player.combat.damage_bonus >= starting_damage + 1.0
	ok = ok and player.health.max_health >= starting_max_health + 10.0
	ok = ok and collected_items.size() == 2
	ok = ok and world.save_world_state()
	world.free()

	GameManager.resume_requested = true
	var restored := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 4)
	var restored_player := restored.player
	ok = ok and restored.current_region_id == &"base:dungeon"
	ok = ok and restored_player.experience.level == 2
	ok = ok and restored_player.experience.total_experience == 120
	ok = ok and restored.entity_repository.get_loaded_entity(BANDIT_A) == null
	ok = ok and restored.entity_repository.get_loaded_entity(BANDIT_B) == null
	for item_id in collected_items:
		ok = ok and restored_player.inventory.count_item(item_id) >= collected_items.count(item_id)
	for enemy_id in [BANDIT_A, BANDIT_B]:
		var restored_drop := _find_drop(restored, enemy_id)
		ok = ok and restored_drop != null and restored_drop.is_collected()
	restored.free()
	GameManager.resume_requested = false
	if not ok:
		push_error("dungeon XP, level-up, equipment loot, or persistence loop failed")
	return ok


func _find_drop(
	world: WorldSession,
	enemy_persistent_id: StringName,
) -> LootDropInteractable3D:
	var root := world.region_service.get_current_region_root()
	return _find_drop_recursive(root, enemy_persistent_id)


func _find_drop_recursive(
	node: Node,
	enemy_persistent_id: StringName,
) -> LootDropInteractable3D:
	if node == null:
		return null
	if node is LootDropInteractable3D:
		var drop := node as LootDropInteractable3D
		if drop.source_enemy_persistent_id == enemy_persistent_id:
			return drop
	for child in node.get_children():
		var found := _find_drop_recursive(child, enemy_persistent_id)
		if found != null:
			return found
	return null
