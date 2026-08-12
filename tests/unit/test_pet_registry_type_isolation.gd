extends RefCounted


func run() -> bool:
	var legacy := PetDefinition.new()
	legacy.id = &"test_shared_pet_id"
	legacy.display_name = "Legacy Pet"
	var companion := _companion_definition(&"test_shared_pet_id")

	ResourceRegistry.register_pet(legacy)
	ResourceRegistry.register_pet_companion(companion)

	var ok := ResourceRegistry.get_pet(legacy.id) == legacy
	ok = ok and ResourceRegistry.get_pet_companion(companion.id) == companion
	ok = ok and ResourceRegistry.get_all_pet_companions().has(companion)
	if not ok:
		push_error("legacy pet and companion definition registries are not type-isolated")
	return ok


func _companion_definition(id: StringName) -> PetCompanionDefinition:
	var species := PetSpeciesDefinition.new()
	species.id = &"registry_species"
	species.display_name = "Registry Species"
	var personality := PetPersonalityProfile.new()
	personality.id = &"registry_personality"
	personality.display_name = "Registry Personality"
	var attributes := PetAttributeProfile.new()
	var definition := PetCompanionDefinition.new()
	definition.id = id
	definition.display_name = "Companion Pet"
	definition.species = species
	definition.personality = personality
	definition.base_attributes = attributes
	return definition
