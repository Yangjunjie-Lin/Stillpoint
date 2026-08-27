extends RefCounted


func run() -> bool:
	var service := ActorEconomyService.new()
	service.setup(null, null)
	var state := service.get_worksite_state(&"worksite:town_smithy")
	var business := service.get_business_state(&"business:stillpoint_smithy")
	var ok: bool = state != null and business != null \
		and business.get_treasury_balance() == 500
	business.restore_treasury(377)
	state.lifetime_work_units = 42.5
	state.active_worker_ids = [&"npc:blacksmith:001"]
	var saved := service.capture_save_data()
	var restored := ActorEconomyService.new()
	restored.setup(null, null)
	ok = restored.restore_save_data(saved) and ok
	var restored_state := restored.get_worksite_state(&"worksite:town_smithy")
	var restored_business := restored.get_business_state(&"business:stillpoint_smithy")
	ok = ok and restored_business.get_treasury_balance() == 377
	ok = ok and is_equal_approx(restored_state.lifetime_work_units, 42.5)
	ok = ok and restored_state.active_worker_ids == [&"npc:blacksmith:001"]
	service.free()
	restored.free()
	if not ok:
		push_error("business treasury/worksite runtime persistence failed")
	return ok
