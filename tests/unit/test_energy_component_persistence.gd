extends RefCounted


func run() -> bool:
	var energy := EnergyComponent.new()
	energy.max_energy = 120.0
	energy.current_energy = 35.0
	energy.is_fatigued = true

	var captured := energy.capture_state()
	var restored := EnergyComponent.new()
	restored.restore_state(captured)

	var ok := is_equal_approx(restored.max_energy, 120.0)
	ok = ok and is_equal_approx(restored.current_energy, 35.0)
	ok = ok and restored.is_fatigued
	if not ok:
		push_error("energy capture/restore roundtrip failed")
	energy.free()
	restored.free()
	return ok
