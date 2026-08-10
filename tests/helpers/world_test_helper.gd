class_name WorldTestHelper
extends RefCounted

const WORLD_SCENE := "res://scenes/world/world_session.tscn"


static func boot_world(tree: SceneTree) -> WorldSession:
	var packed: PackedScene = load(WORLD_SCENE) as PackedScene
	var world := packed.instantiate() as WorldSession
	tree.root.add_child(world)
	return world


static func await_frames(tree: SceneTree, count: int = 2) -> void:
	for _i in count:
		await tree.physics_frame


static func find_npc(world: WorldSession, npc_name: String) -> NPCController:
	var root := world.region_service.get_current_region_root()
	if root == null:
		return null
	return root.find_child(npc_name, true, false) as NPCController


static func find_pickup(world: WorldSession, node_name: String = "HerbPickup") -> PickupInteractable3D:
	var root := world.region_service.get_current_region_root()
	if root == null:
		return null
	return root.find_child(node_name, true, false) as PickupInteractable3D


static func select_hotbar_item(player: PlayerController3D, item_id: StringName) -> bool:
	if player == null or player.inventory == null:
		return false
	for hotbar_index in player.hotbar.slot_refs.size():
		var inventory_index := player.hotbar.slot_refs[hotbar_index]
		var stack := player.inventory.get_slot(inventory_index)
		if stack != null and not stack.is_empty() and stack.item_id == item_id:
			return player.hotbar.select_index(hotbar_index)
	return false


static func start_mira_quest_via_dialogue(world: WorldSession) -> void:
	world.start_dialogue(find_npc(world, "Mira"))
	world.apply_dialogue_choice(0)
	await Engine.get_main_loop().process_frame


static func deliver_herb_via_dialogue(world: WorldSession) -> void:
	world.start_dialogue(find_npc(world, "Mira"))
	world.apply_dialogue_choice(0)
	await Engine.get_main_loop().process_frame
