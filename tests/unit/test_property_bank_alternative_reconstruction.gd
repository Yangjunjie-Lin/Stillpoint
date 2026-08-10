extends RefCounted


func run() -> bool:
	var service := PropertyBankService.new()
	service.reset_defaults()
	var ok := service.process_offline_elapsed(service.offline_reclaim_seconds)
	ok = ok and service.get_total_funds() == 3000
	ok = ok and service.construct_house(&"building:player_courtyard_house")
	ok = ok and service.has_active_house()
	ok = ok and service.current_house_id == &"building:player_courtyard_house"
	ok = ok and service.home_storage.slot_count == 60
	ok = ok and service.get_total_funds() == 800
	ok = ok and not service.construct_house(&"building:player_townhouse")
	service.free()
	if not ok:
		push_error("alternative private-home construction or pricing failed")
	return ok
