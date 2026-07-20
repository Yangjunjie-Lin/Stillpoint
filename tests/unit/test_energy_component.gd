extends RefCounted


func run() -> bool:
	var energy := EnergyComponent.new()
	energy.current_energy = 100.0
	if not energy.spend(25.0):
		return false
	var before := energy.current_energy
	energy.tick(0.5, true, false)
	return energy.current_energy < before
