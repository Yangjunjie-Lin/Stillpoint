extends RefCounted


func run() -> bool:
	var health := HealthComponent.new()
	var ok := true

	health.from_dict({
		"max_health": -5.0,
		"current_health": 999.0,
		"defense": -2.0,
		"death_recorded": false,
	})
	ok = ok and is_equal_approx(health.max_health, 1.0)
	ok = ok and is_equal_approx(health.current_health, 1.0)
	ok = ok and is_equal_approx(health.defense, 0.0)

	health.from_dict({
		"max_health": 100.0,
		"current_health": NAN,
		"defense": 0.0,
		"death_recorded": false,
	})
	ok = ok and is_equal_approx(health.current_health, 0.0)

	health.free()
	if not ok:
		push_error("Health restore validation failed")
	return ok
