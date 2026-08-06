class_name WorldSimulationService
extends Node
## Minimal simulation for unloaded entities (schedule, respawn timers).

enum SimulationMode {
	FULL,
	REDUCED,
	VIRTUAL,
}

var _entity_repository: WorldEntityRepository


func setup(repository: WorldEntityRepository) -> void:
	_entity_repository = repository


func get_mode_for_entity(persistent_id: StringName) -> int:
	if _entity_repository != null and _entity_repository.get_loaded_entity(persistent_id) != null:
		return SimulationMode.FULL
	return SimulationMode.VIRTUAL


func tick_virtual(delta_minutes: float) -> void:
	if _entity_repository == null:
		return
	# Phase 1: placeholder for schedule advancement on snapshots.
	pass
