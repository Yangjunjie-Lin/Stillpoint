extends RefCounted

const BANK_CLERK_ID := &"base:town/npc/bank_clerk_0001"
const BLACKSMITH_ID := &"base:town/npc/blacksmith_0001"


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var bank_clerk := world.entity_repository.get_loaded_entity(BANK_CLERK_ID) as NPCController
	var blacksmith := world.entity_repository.get_loaded_entity(BLACKSMITH_ID) as NPCController
	var ok := _validate_spawn(bank_clerk, &"bank_clerk", BANK_CLERK_ID) \
		and _validate_spawn(blacksmith, &"blacksmith", BLACKSMITH_ID)
	for npc in [bank_clerk, blacksmith]:
		if npc == null:
			continue
		ok = world.start_dialogue(npc) and ok
		await tree.process_frame
		ok = world.dialogue_coordinator.get_active_npc() == npc and ok
		world.cancel_active_dialogue()
		await tree.process_frame
	if bank_clerk != null and blacksmith != null:
		var clerk_model := bank_clerk.get_node_or_null("VisualRoot/CharacterModel") as StylizedNPCModel
		var smith_model := blacksmith.get_node_or_null("VisualRoot/CharacterModel") as StylizedNPCModel
		ok = ok and clerk_model != null and smith_model != null and clerk_model != smith_model
		if clerk_model != null and smith_model != null:
			var clerk_signature := clerk_model.get_visual_signature()
			var smith_signature := smith_model.get_visual_signature()
			ok = ok and StringName(clerk_signature.get("persistent_id", "")) == BANK_CLERK_ID
			ok = ok and StringName(smith_signature.get("persistent_id", "")) == BLACKSMITH_ID
			ok = ok and clerk_signature != smith_signature
	var region_root := world.region_service.get_current_region_root()
	var smithy := region_root.find_child("HouseStillpointBlacksmith", true, false) \
		if region_root != null else null
	ok = ok and smithy is StaticBody3D
	if smithy != null:
		ok = ok and String(smithy.get_meta("ontology_id", "")) \
			== "building:stillpoint_blacksmith"
	var bank_trade := region_root.get_node_or_null("Interactables/BankEquipmentCounter") \
		as CommerceInteractable3D if region_root != null else null
	var smith_trade := region_root.get_node_or_null("Interactables/BlacksmithCounter") \
		as CommerceInteractable3D if region_root != null else null
	ok = ok and bank_trade != null \
		and bank_trade.shop_id == &"shop:stillpoint_bank_equipment"
	ok = ok and smith_trade != null \
		and smith_trade.shop_id == &"shop:stillpoint_blacksmith_equipment" \
		and smith_trade.forge_recipe_ids == [&"forge:greywake_iron_sword"]
	var commerce_menu := world.get_node_or_null("WorldUI/CommerceMenu") as CommerceMenu
	if bank_trade != null:
		bank_trade.interact(world.player, InteractionContext.new(world.player))
		await tree.process_frame
		ok = ok and commerce_menu != null and commerce_menu.is_open()
		if commerce_menu != null:
			commerce_menu.close_menu()
	if smith_trade != null:
		smith_trade.interact(world.player, InteractionContext.new(world.player))
		await tree.process_frame
		ok = ok and commerce_menu != null and commerce_menu.is_open()
		if commerce_menu != null:
			commerce_menu.close_menu()
	world.free()
	if not ok:
		push_error("town bank clerk, blacksmith, or smithy entity contract failed")
	return ok


func _validate_spawn(
	actor: NPCController,
	definition_id: StringName,
	persistent_id: StringName,
) -> bool:
	if actor == null or actor.npc_definition == null:
		return false
	var identity := actor.get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity
	var interactable := actor.get_node_or_null("NPCInteractable") as NPCInteractable
	return actor.npc_definition.id == definition_id \
		and actor.character_id == definition_id \
		and actor.region_id == &"base:town" \
		and actor.get_parent().name == &"DynamicEntities" \
		and identity != null \
		and identity.definition_id == definition_id \
		and identity.persistent_id == persistent_id \
		and identity.region_id == &"base:town" \
		and interactable != null \
		and interactable.region_id == &"base:town"
