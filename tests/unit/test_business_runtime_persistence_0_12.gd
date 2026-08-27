extends RefCounted


func run() -> bool:
	var first := ActorEconomyService.new()
	var second := ActorEconomyService.new()
	first.setup(null, null)
	second.setup(null, null)
	var first_smithy := first.get_business_state(&"business:stillpoint_smithy")
	var second_smithy := second.get_business_state(&"business:stillpoint_smithy")
	var ok: bool = first_smithy != null and second_smithy != null
	ok = ok and first_smithy != second_smithy
	ok = ok and first_smithy.get_treasury_balance() == 500
	ok = ok and first_smithy.inventory.count_item(&"iron_ore") == 12
	first_smithy.debit(25, &"test")
	first_smithy.inventory.remove_item(&"iron_ore", 2)
	first_smithy.note_stock_changed(&"test")
	ok = ok and second_smithy.get_treasury_balance() == 500
	ok = ok and second_smithy.inventory.count_item(&"iron_ore") == 12

	var saved := first.capture_save_data()
	var restored := ActorEconomyService.new()
	restored.setup(null, null)
	ok = restored.restore_save_data(saved) and ok
	var restored_smithy := restored.get_business_state(&"business:stillpoint_smithy")
	ok = ok and JSON.stringify(restored_smithy.to_dict()) \
		== JSON.stringify(first_smithy.to_dict())

	var legacy := {
		"section_version": 1,
		"worksites": {
			"worksite:town_smithy": {
				"worksite_id": "worksite:town_smithy",
				"payroll_balance": 377,
				"lifetime_work_units": 12.5,
				"active_worker_ids": ["npc:legacy"],
				"last_processed_day": 2,
			},
		},
	}
	var migrated := ActorEconomyService.new()
	migrated.setup(null, null)
	ok = migrated.restore_save_data(legacy) and ok
	ok = ok and migrated.get_business_state(
		&"business:stillpoint_smithy"
	).get_treasury_balance() == 377
	var migrated_saved := migrated.capture_save_data()
	ok = ok and int(migrated_saved.get("section_version", 0)) == 2
	ok = ok and not JSON.stringify(migrated_saved).contains("payroll_balance")
	ok = migrated.restore_save_data(migrated_saved) and ok
	ok = ok and migrated.get_business_state(
		&"business:stillpoint_smithy"
	).get_treasury_balance() == 377
	first.free()
	second.free()
	restored.free()
	migrated.free()
	if not ok:
		push_error("business initialization, isolation, persistence, or payroll migration failed")
	return ok
