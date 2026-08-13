extends RefCounted


const PET_EQUIPMENT_IDS: Array[StringName] = [
	&"mossfox_collar",
	&"mossfox_harness",
	&"quiet_bell_charm",
	&"stonehound_guard_collar",
	&"stonehound_back_guard",
	&"stonehound_oath_charm",
	&"cloudowl_flight_band",
	&"cloudowl_wing_harness",
	&"cloudowl_talon_charm",
]

const EXPECTED_BY_SPECIES := {
	"mossfox": ["mossfox_collar", "mossfox_harness", "quiet_bell_charm"],
	"stonehound": [
		"stonehound_guard_collar",
		"stonehound_back_guard",
		"stonehound_oath_charm",
	],
	"cloudowl": [
		"cloudowl_flight_band",
		"cloudowl_wing_harness",
		"cloudowl_talon_charm",
	],
}


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var menu := world.get_node_or_null("WorldUI/PetCompanionMenu") as PetCompanionMenu
	var ok := menu != null and world.player != null and world.player.inventory != null
	if ok:
		# The authored new-adventure backpack is deliberately close to capacity
		# and already contains Pip's starter set. Use an exact nine-item fixture so
		# this test measures species filtering rather than starter grants/capacity.
		world.player.inventory.from_dict({"slots": []})
		for item_id in PET_EQUIPMENT_IDS:
			var added := world.player.inventory.add_item(item_id, 1)
			if added != 1:
				push_error("could not add pet equipment %s to acceptance inventory" % item_id)
				ok = false
		for pet in world.get_owned_pets():
			var species_id := String(pet.pet_definition.id)
			ok = ok and EXPECTED_BY_SPECIES.has(species_id)
			if not EXPECTED_BY_SPECIES.has(species_id):
				continue
			menu.open_menu(pet)
			ok = ok and menu.is_open()
			ok = ok and menu.name_label.text == pet.get_display_name()
			ok = ok and menu.proactive_check.button_pressed \
				== pet.runtime_state.is_auto_dialogue_enabled()
			var visible_ids := _visible_equipment_ids(menu, world.player.inventory)
			visible_ids.sort()
			var expected_ids: Array = EXPECTED_BY_SPECIES[species_id].duplicate()
			expected_ids.sort()
			if visible_ids != expected_ids:
				push_error("%s equipment filter returned %s, expected %s" % [
					species_id, visible_ids, expected_ids,
				])
				ok = false
			menu.close_menu()
	world.free()
	if not ok:
		push_error("pet companion menu did not isolate instance state and species-fitted equipment")
	return ok


func _visible_equipment_ids(
	menu: PetCompanionMenu,
	inventory: InventoryComponent,
) -> Array:
	var result: Array = []
	for row in menu.equipment_list.item_count:
		var slot_index := int(menu.equipment_list.get_item_metadata(row))
		var stack := inventory.get_slot(slot_index)
		if stack != null and not stack.is_empty():
			result.append(String(stack.item_id))
	return result
