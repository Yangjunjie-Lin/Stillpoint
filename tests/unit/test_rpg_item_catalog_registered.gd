extends RefCounted


func run() -> bool:
	var expected: Array[StringName] = [
		&"herb",
		&"gift_box",
		&"training_sword",
		&"padded_vest",
		&"wanderer_charm",
		&"trail_snack",
		&"field_pick",
	]
	var ok := true
	for item_id in expected:
		var definition := ResourceRegistry.get_item(item_id)
		ok = ok and definition != null and definition.icon != null
	if not ok:
		push_error("nested RPG item catalog or icons were not registered")
	return ok
