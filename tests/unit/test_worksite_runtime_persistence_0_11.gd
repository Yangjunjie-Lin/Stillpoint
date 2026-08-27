extends RefCounted


func run() -> bool:
	var service := ActorEconomyService.new()
	service.setup(null, null)
	var state := service.get_worksite_state(&"worksite:town_smithy")
	var ok: bool = state != null and state.payroll_balance == 500
	state.payroll_balance = 377
	state.lifetime_work_units = 42.5
	state.active_worker_ids = [&"npc:blacksmith:001"]
	var saved := service.capture_save_data()
	var restored := ActorEconomyService.new()
	restored.setup(null, null)
	ok = restored.restore_save_data(saved) and ok
	var restored_state := restored.get_worksite_state(&"worksite:town_smithy")
	ok = ok and restored_state.payroll_balance == 377
	ok = ok and is_equal_approx(restored_state.lifetime_work_units, 42.5)
	ok = ok and restored_state.active_worker_ids == [&"npc:blacksmith:001"]
	service.free()
	restored.free()
	if not ok:
		push_error("finite worksite payroll runtime persistence failed")
	return ok
