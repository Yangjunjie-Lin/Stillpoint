extends RefCounted


func run() -> bool:
	var valid := {
		"world_time": {"day": 1, "hour": 8, "minute": 0, "paused": false, "time_scale": 1.0},
		"discovered_regions": ["base:town"],
		"id_counters": {},
		"property_banking": {
			"section_version": 1,
			"wallet_balance": 500,
			"bank_balance": 0,
			"house_status": "owned",
			"home_storage": {"slots": []},
			"bank_storage": {"slots": []},
		},
	}
	var ok := SaveSlotService._is_valid_global_world_section(valid)
	var corrupt := valid.duplicate(true)
	(corrupt["property_banking"] as Dictionary)["home_storage"] = {
		"slots": [{"item_id": "herb", "quantity": NAN}],
	}
	ok = ok and not SaveSlotService._is_valid_global_world_section(corrupt)
	corrupt = valid.duplicate(true)
	(corrupt["property_banking"] as Dictionary)["bank_storage"] = {"slots": "lost"}
	ok = ok and not SaveSlotService._is_valid_global_world_section(corrupt)
	if not ok:
		push_error("corrupt private-storage Save v4 data was not rejected")
	return ok
