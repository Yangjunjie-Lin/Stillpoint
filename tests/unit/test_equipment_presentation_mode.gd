extends RefCounted


func run() -> bool:
	var equipment := EquipmentComponent.new()
	var signal_counter := [0]
	equipment.presentation_mode_changed.connect(func(_mode: StringName) -> void:
		signal_counter[0] = int(signal_counter[0]) + 1
	)
	var ok := equipment.get_presentation_mode() == EquipmentComponent.PRESENTATION_PROFESSION
	ok = ok and equipment.get_slots_for_presentation(
		EquipmentComponent.PRESENTATION_PROFESSION
	) == EquipmentComponent.ATTRIBUTE_SLOTS
	ok = ok and equipment.get_slots_for_presentation(
		EquipmentComponent.PRESENTATION_DECORATIVE
	) == EquipmentComponent.DECORATIVE_SLOTS
	ok = ok and equipment.toggle_presentation_mode() == EquipmentComponent.PRESENTATION_DECORATIVE
	ok = ok and int(signal_counter[0]) == 1
	ok = ok and not equipment.set_presentation_mode(EquipmentComponent.PRESENTATION_DECORATIVE)
	ok = ok and int(signal_counter[0]) == 1

	var saved := equipment.to_dict()
	var restored := EquipmentComponent.new()
	ok = ok and restored.from_dict(saved)
	ok = ok and restored.get_presentation_mode() == EquipmentComponent.PRESENTATION_DECORATIVE
	ok = ok and restored.from_dict({"section_version": 2, "slots": {}})
	ok = ok and restored.get_presentation_mode() == EquipmentComponent.PRESENTATION_PROFESSION
	ok = ok and restored.from_dict({
		"section_version": EquipmentComponent.SECTION_VERSION,
		"slots": {},
		"presentation_mode": "invalid",
	})
	ok = ok and restored.get_presentation_mode() == EquipmentComponent.PRESENTATION_PROFESSION
	var before_future := restored.to_dict()
	ok = ok and not restored.from_dict({
		"section_version": EquipmentComponent.SECTION_VERSION + 1,
		"slots": {},
		"presentation_mode": "decorative",
	})
	ok = ok and restored.to_dict() == before_future
	equipment.free()
	restored.free()
	if not ok:
		push_error("equipment presentation mode toggle or persistence compatibility failed")
	return ok
