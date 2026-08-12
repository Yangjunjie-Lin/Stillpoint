extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var pet := world.companion_root.get_node_or_null("Pet") as PetController
	var menu := world.get_node_or_null("WorldUI/PetCompanionMenu") as PetCompanionMenu
	var model := pet.get_node_or_null("VisualRoot/PetModel") as StylizedPetModel if pet else null
	var ok := pet != null and menu != null and model != null
	if ok:
		ok = ok and pet.pet_definition != null and pet.pet_definition.is_valid()
		ok = ok and pet.runtime_state.get_pet_instance_id() == &"base:town/companion/pet"
		ok = ok and model.get_visual_signature().get("articulated_legs", 0) == 4
		ok = ok and world.interaction_index.get_registered_count() > 0
		ok = ok and world.player.inventory.count_item(&"mossfox_collar") == 1
		ok = ok and world.open_pet_companion(pet) and menu.is_open()
		ok = ok and not menu.show_reply({
			"pet_instance_id": "base:player/pet/cloudowl_0001",
			"reply_text": "This belongs to another companion.",
		})
		ok = ok and menu.show_reply({
			"pet_instance_id": String(pet.runtime_state.get_pet_instance_id()),
			"reply_text": "Pip reply routing is isolated.",
		})
		menu.close_menu()
		var collar_slot := _find_slot(world.player.inventory, &"mossfox_collar")
		ok = ok and collar_slot >= 0 and pet.equip_from_inventory(
			world.player.inventory, collar_slot, &"collar"
		)
		ok = ok and pet.runtime_state.get_equipped_item(&"collar") == &"mossfox_collar"
		var snack_slot := _find_slot(world.player.inventory, &"trail_snack")
		var snacks_before := world.player.inventory.count_item(&"trail_snack")
		ok = ok and pet.feed_from_inventory(world.player.inventory, snack_slot)
		ok = ok and world.player.inventory.count_item(&"trail_snack") == snacks_before - 1
		var saved := pet.to_dict()
		pet.toggle_mode()
		pet.from_dict(saved)
		ok = ok and pet.runtime_state.get_equipped_item(&"collar") == &"mossfox_collar"
		ok = ok and pet.runtime_state.get_pet_instance_id() == &"base:town/companion/pet"
	world.free()
	if not ok:
		push_error("pet companion world/UI/feed/equipment/save vertical slice failed")
	return ok


func _find_slot(inventory: InventoryComponent, item_id: StringName) -> int:
	for index in inventory.slot_count:
		var stack := inventory.get_slot(index)
		if stack != null and stack.item_id == item_id and stack.quantity > 0:
			return index
	return -1
