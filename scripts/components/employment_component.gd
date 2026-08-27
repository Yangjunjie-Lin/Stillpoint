class_name EmploymentComponent
extends Node
## Persistent per-actor employment, work summary, and economic replay high-water mark.

signal employment_changed

const SECTION_VERSION := 1

var current_contract: EmploymentContract = null
var last_work_day: int = 0
var last_work_result: Dictionary = {}
var economic_sequence: int = 0
var completed_work_actions: int = 0
var lifetime_income: int = 0


func initialize_contract(contract: EmploymentContract) -> bool:
	if current_contract != null or contract == null or not contract.is_active():
		return false
	current_contract = EmploymentContract.from_dict(contract.to_dict())
	employment_changed.emit()
	return true


func expected_next_sequence() -> int:
	return economic_sequence + 1


func can_commit_sequence(sequence: int) -> bool:
	return sequence == expected_next_sequence()


func commit_sequence(sequence: int) -> bool:
	if not can_commit_sequence(sequence):
		return false
	economic_sequence = sequence
	employment_changed.emit()
	return true


func record_work(result: WorkResult) -> void:
	if result == null:
		return
	last_work_day = result.world_day
	last_work_result = result.to_dict()
	completed_work_actions += 1
	lifetime_income += maxi(0, result.wage)
	employment_changed.emit()


func to_dict() -> Dictionary:
	return {
		"section_version": SECTION_VERSION,
		"contract": current_contract.to_dict() if current_contract != null else {},
		"last_work_day": last_work_day,
		"last_work_result": last_work_result.duplicate(true),
		"economic_sequence": economic_sequence,
		"completed_work_actions": completed_work_actions,
		"lifetime_income": lifetime_income,
	}


func from_dict(data: Dictionary) -> bool:
	var version := int(data.get("section_version", SECTION_VERSION))
	if version < 0 or version > SECTION_VERSION:
		return false
	var raw_contract: Variant = data.get("contract", {})
	current_contract = EmploymentContract.from_dict(raw_contract) if raw_contract is Dictionary and not (raw_contract as Dictionary).is_empty() else null
	last_work_day = maxi(0, int(data.get("last_work_day", 0)))
	var raw_result: Variant = data.get("last_work_result", {})
	last_work_result = WorkResult.from_dict(raw_result as Dictionary).to_dict() \
		if raw_result is Dictionary and not (raw_result as Dictionary).is_empty() else {}
	economic_sequence = maxi(0, int(data.get("economic_sequence", 0)))
	completed_work_actions = maxi(0, int(data.get("completed_work_actions", 0)))
	lifetime_income = maxi(0, int(data.get("lifetime_income", 0)))
	employment_changed.emit()
	return true


func get_persistence_key() -> StringName:
	return &"employment"


func capture_state() -> Dictionary:
	return to_dict()


func restore_state(data: Dictionary) -> void:
	from_dict(data)


func get_state_version() -> int:
	return SECTION_VERSION
