extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var pets := world.get_owned_pets()
	var expected := {
		"mossfox": "mossfox",
		"stonehound": "stonehound",
		"cloudowl": "cloudowl",
	}
	var definitions: Dictionary = {}
	var instances: Dictionary = {}
	var ok := pets.size() >= expected.size()
	var invalid_scene := PackedScene.new()
	var invalid_root := Node3D.new()
	invalid_root.name = "InvalidPetSceneRoot"
	ok = ok and invalid_scene.pack(invalid_root) == OK
	invalid_root.free()
	var invalid_definition := (
		ResourceRegistry.get_pet_companion(&"cloudowl").duplicate(true)
		as PetCompanionDefinition
	)
	invalid_definition.id = &"invalid_scene_pet"
	invalid_definition.scene = invalid_scene
	ok = ok and world._create_pet_actor(
		invalid_definition, &"base:test/pet/invalid_scene"
	) == null
	for pet in pets:
		var definition_id := String(pet.pet_definition.id)
		var instance_id := String(pet.runtime_state.get_pet_instance_id())
		definitions[definition_id] = true
		instances[instance_id] = true
		var model := pet.get_node_or_null("VisualRoot/PetModel") as StylizedPetModel
		var interactable := pet.get_node_or_null("PetInteractable") as PetInteractable
		if expected.has(definition_id):
			ok = ok and model != null \
				and str(model.get_visual_signature().get("archetype", "")) \
					== str(expected[definition_id])
			if model != null:
				var expected_style := {
					"mossfox": "field_harness",
					"stonehound": "layered_guard",
					"cloudowl": "flight_rig",
				}
				var expected_style_id: String = str(expected_style.get(definition_id, ""))
				ok = ok and str(model.get_visual_signature().get("equipment_style", "")) == expected_style_id
			ok = ok and pet.pet_definition.scene != null
			if definition_id != "mossfox":
				ok = ok and pet.scene_file_path == "res://scenes/pets/pet_companion_actor.tscn"
		ok = ok and interactable != null \
			and interactable.get_interaction_text(world.player).contains(
				pet.get_display_name()
			)
	for definition_id in expected:
		ok = ok and definitions.has(definition_id)
	ok = ok and instances.size() == pets.size()
	# RegionRuntimeService clears its interaction index during unload. Every
	# persistent, following companion must be registered again in the new region.
	ok = ok and world.transition_to(&"base:wilderness")
	await WorldTestHelper.await_frames(tree, 2)
	var nearby := world.interaction_index.query_nearby(world.player, 6.0)
	for pet in pets:
		var interactable := pet.get_node_or_null("PetInteractable") as PetInteractable
		ok = ok and pet.is_present_in_current_region() \
			and interactable != null and nearby.has(interactable)

	# The previous schema stored one placeholder pet dictionary. It must migrate
	# onto Pip's canonical instance instead of being discarded before controller
	# migration gets a chance to preserve its state.
	world.restore_companions({"pets": {
		"pet_id": "placeholder_pet",
		"bond": 37.5,
		"mode": PetController.Mode.STAY,
		"unlocked": true,
		"region_id": "base:wilderness",
	}})
	var migrated_pip := _pet_by_definition(world.get_owned_pets(), &"mossfox")
	ok = ok and migrated_pip != null \
		and migrated_pip.runtime_state.get_pet_instance_id() == &"base:town/companion/pet" \
		and migrated_pip.runtime_state.get_affection() == 37.5 \
		and not migrated_pip.runtime_state.is_following() \
		and world.get_active_pet() == migrated_pip
	var pet_count_before_tamper := world.get_owned_pets().size()
	world.restore_companions({"pets": [{
		"section_version": PetRuntimeState.SECTION_VERSION,
		"definition_id": "cloudowl",
		"instance_id": "base:player/main",
		"owner_id": "base:player/main",
		"behavior": {},
		"vitals": {},
		"attributes": {},
		"skill_progress": {},
		"equipment": {},
	}]})
	ok = ok and world.get_owned_pets().size() == pet_count_before_tamper \
		and world.get_pet_by_instance_id(&"base:player/main") == null \
		and world.entity_repository.get_loaded_entity(&"base:player/main") == world.player

	var owl := _pet_by_definition(pets, &"cloudowl")
	if owl != null:
		owl.set_following(false)
		owl.runtime_state.choose_lifestyle(&"explore")
		ok = ok and world.set_active_pet(owl.runtime_state.get_pet_instance_id())
	var saved := world.capture_companions()
	ok = ok and saved.get("pets", []) is Array \
		and (saved.get("pets", []) as Array).size() == pets.size()
	if owl != null:
		owl.set_following(true)
	world.restore_companions(saved)
	var restored_owl := _pet_by_definition(world.get_owned_pets(), &"cloudowl")
	ok = ok and restored_owl != null \
		and not restored_owl.runtime_state.is_following() \
		and restored_owl.runtime_state.get_lifestyle_id() == &"explore" \
		and world.get_active_pet() == restored_owl

	world.free()
	if not ok:
		push_error("multiple pet definitions did not produce isolated world instances")
	return ok


func _pet_by_definition(
	pets: Array[PetController],
	definition_id: StringName,
) -> PetController:
	for pet in pets:
		if pet.pet_definition != null and pet.pet_definition.id == definition_id:
			return pet
	return null
