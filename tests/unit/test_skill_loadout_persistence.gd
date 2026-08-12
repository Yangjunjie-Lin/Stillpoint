extends RefCounted


func run() -> bool:
	var loadout := SkillLoadoutComponent.new()
	var ok := loadout.get_slot_skill_id(0) == &"power_strike"
	ok = ok and loadout.configure_slot(2, &"")
	var saved := loadout.to_dict()
	var restored := SkillLoadoutComponent.new()
	ok = ok and restored.from_dict(saved)
	ok = ok and restored.get_slot_skill_id(0) == &"power_strike"
	ok = ok and restored.get_slot_skill_id(2) == &""
	ok = ok and restored.from_dict({})
	ok = ok and restored.get_slot_skill_id(2) == &"guard_counter"
	var duplicate_payload := {
		"section_version": SkillLoadoutComponent.SECTION_VERSION,
		"active_slots": ["power_strike", "power_strike", "", ""],
	}
	ok = ok and not restored.from_dict(duplicate_payload)
	loadout.free()
	restored.free()
	if not ok:
		push_error("skill loadout persistence or legacy default recovery failed")
	return ok
