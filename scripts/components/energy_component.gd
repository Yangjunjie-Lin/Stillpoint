class_name EnergyComponent
extends Node
## Stamina/energy for movement, combat, work, and skills.

signal energy_changed(current: float, maximum: float)
signal depleted
signal fatigued

@export var max_energy: float = 100.0
@export var regen_per_second: float = 8.0
@export var run_drain_per_second: float = 12.0
@export var guard_drain_per_second: float = 18.0

var current_energy: float = 100.0
var is_fatigued: bool = false


func _ready() -> void:
	current_energy = max_energy
	energy_changed.emit(current_energy, max_energy)


func can_spend(amount: float) -> bool:
	return current_energy >= amount


func spend(amount: float) -> bool:
	if amount <= 0.0:
		return true
	if current_energy < amount:
		return false
	current_energy = maxf(0.0, current_energy - amount)
	energy_changed.emit(current_energy, max_energy)
	if current_energy <= 0.0:
		is_fatigued = true
		depleted.emit()
		fatigued.emit()
	return true


func restore(amount: float) -> void:
	if amount <= 0.0:
		return
	current_energy = minf(max_energy, current_energy + amount)
	if current_energy > max_energy * 0.2:
		is_fatigued = false
	energy_changed.emit(current_energy, max_energy)


func tick(delta: float, running: bool = false, guarding: bool = false) -> void:
	var drain := 0.0
	if running:
		drain += run_drain_per_second * delta
	if guarding:
		drain += guard_drain_per_second * delta
	if drain > 0.0:
		spend(drain)
	elif current_energy < max_energy:
		restore(regen_per_second * delta)


func to_dict() -> Dictionary:
	return {
		"max_energy": max_energy,
		"current_energy": current_energy,
		"is_fatigued": is_fatigued,
	}


func from_dict(data: Dictionary) -> void:
	max_energy = maxf(1.0, float(data.get("max_energy", max_energy)))
	current_energy = clampf(float(data.get("current_energy", current_energy)), 0.0, max_energy)
	is_fatigued = bool(data.get("is_fatigued", false))
	energy_changed.emit(current_energy, max_energy)
