extends RefCounted


func run() -> bool:
	var status := StatusEffectComponent.new()
	status.refresh_policy = StatusEffectComponent.RefreshPolicy.RESET_DURATION
	var ok := true

	status.apply(&"speed", 5.0, 0.0)
	ok = ok and status.has_effect(&"speed", 1.0)
	ok = ok and is_equal_approx(status.remaining(&"speed", 1.0), 4.0)

	# Reset duration on re-apply.
	status.apply(&"speed", 5.0, 3.0)
	ok = ok and is_equal_approx(status.remaining(&"speed", 3.0), 5.0)

	status.update_clock(9.0)
	ok = ok and not status.has_effect(&"speed", 9.0)

	status.apply(&"shield", INF, 10.0)
	var serialized := status.to_dict(10.0)
	ok = ok and str(serialized.get("shield", "")) == "inf"
	status.clear_all()
	status.from_dict(serialized, 50.0)
	ok = ok and status.has_effect(&"shield", 50.0)
	ok = ok and is_inf(status.remaining(&"shield", 50.0))

	status.clear_all()
	status.refresh_policy = StatusEffectComponent.RefreshPolicy.EXTEND_DURATION
	status.apply(&"double", 2.0, 0.0)
	status.apply(&"double", 2.0, 1.0)
	ok = ok and is_equal_approx(status.remaining(&"double", 1.0), 3.0)

	status.free()
	if not ok:
		push_error("StatusEffectComponent assertions failed")
	return ok
