extends RefCounted


func run() -> bool:
	var health := HealthComponent.new()
	health.max_health = 80.0
	health.current_health = 22.5
	health.defense = 3.0
	health.death_recorded = true

	var captured := health.capture_state()
	var restored := HealthComponent.new()
	restored.restore_state(captured)

	var ok := is_equal_approx(restored.max_health, 80.0)
	ok = ok and is_equal_approx(restored.current_health, 22.5)
	ok = ok and is_equal_approx(restored.defense, 3.0)
	ok = ok and restored.death_recorded
	if not ok:
		push_error("health capture/restore roundtrip failed")
	health.free()
	restored.free()
	return ok
