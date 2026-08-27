class_name WalletComponent
extends Node
## Canonical personal carried-currency capability shared by player and NPC actors.

signal balance_changed(balance: int)
signal transaction_recorded(record: Dictionary)

const SECTION_VERSION := 1
const MAX_RECENT_TRANSACTIONS := 32

@export_range(0, 1000000000, 1) var starting_balance: int = 0

var _balance: int = 0
var _recent_transactions: Array[Dictionary] = []
var _initialized: bool = false


func _ready() -> void:
	if not _initialized:
		_balance = maxi(0, starting_balance)
		_initialized = true


func get_balance() -> int:
	return _balance


func get_total_funds() -> int:
	return _balance


func can_spend(amount: int) -> bool:
	return amount >= 0 and _balance >= amount


func spend_funds(amount: int) -> bool:
	return debit(amount, {"reason": "purchase"})


func debit(amount: int, context: Dictionary = {}) -> bool:
	if amount <= 0 or not can_spend(amount):
		return false
	_balance -= amount
	_record_transaction(-amount, &"debit", context)
	balance_changed.emit(_balance)
	return true


func credit(amount: int, context: Dictionary = {}) -> bool:
	if amount <= 0 or _balance > 1000000000 - amount:
		return false
	_balance += amount
	_record_transaction(amount, &"credit", context)
	balance_changed.emit(_balance)
	return true


func credit_wallet(amount: int) -> int:
	return amount if credit(amount, {"reason": "sale"}) else 0


func restore_balance(amount: int, context: Dictionary = {}) -> bool:
	## Trusted setup/migration entry point. Runtime systems use debit/credit.
	if amount < 0:
		return false
	_balance = amount
	_initialized = true
	if not context.is_empty():
		_record_transaction(amount, &"restore", context)
	balance_changed.emit(_balance)
	return true


func get_recent_transactions() -> Array[Dictionary]:
	return _recent_transactions.duplicate(true)


func to_dict() -> Dictionary:
	return {
		"section_version": SECTION_VERSION,
		"balance": _balance,
		"recent_transactions": _recent_transactions.duplicate(true),
	}


func from_dict(data: Dictionary) -> bool:
	var version := int(data.get("section_version", SECTION_VERSION))
	if version < 0 or version > SECTION_VERSION:
		return false
	_balance = maxi(0, int(data.get("balance", starting_balance)))
	_recent_transactions.clear()
	var raw_history: Variant = data.get("recent_transactions", [])
	if raw_history is Array:
		var start := maxi(0, (raw_history as Array).size() - MAX_RECENT_TRANSACTIONS)
		for index in range(start, (raw_history as Array).size()):
			var raw: Variant = (raw_history as Array)[index]
			if raw is Dictionary:
				_recent_transactions.append((raw as Dictionary).duplicate(true))
	_initialized = true
	balance_changed.emit(_balance)
	return true


func get_persistence_key() -> StringName:
	return &"wallet"


func capture_state() -> Dictionary:
	return to_dict()


func restore_state(data: Dictionary) -> void:
	from_dict(data)


func get_state_version() -> int:
	return SECTION_VERSION


func _record_transaction(amount_delta: int, direction: StringName, context: Dictionary) -> void:
	var record := {
		"actor_id": String(_resolve_actor_id(context)),
		"amount": absi(amount_delta),
		"delta": amount_delta,
		"direction": String(direction),
		"reason": str(context.get("reason", "unspecified")).left(48),
		"counterparty_id": str(context.get("counterparty_id", "")).left(128),
		"worksite_id": str(context.get("worksite_id", "")).left(96),
		"shop_id": str(context.get("shop_id", "")).left(96),
		"proposal_id": str(context.get("proposal_id", "")).left(128),
		"transaction_sequence": maxi(0, int(context.get("transaction_sequence", 0))),
		"world_day": maxi(1, int(context.get("world_day", WorldTimeService.day))),
		"world_hour": clampi(int(context.get("world_hour", WorldTimeService.hour)), 0, 23),
	}
	_recent_transactions.append(record)
	while _recent_transactions.size() > MAX_RECENT_TRANSACTIONS:
		_recent_transactions.pop_front()
	transaction_recorded.emit(record.duplicate(true))


func _resolve_actor_id(context: Dictionary) -> StringName:
	var from_context := StringName(str(context.get("actor_id", "")).strip_edges())
	if from_context != &"":
		return from_context
	var actor := get_parent()
	if actor != null:
		var identity := actor.get_node_or_null("WorldEntityIdentity") as WorldEntityIdentity
		if identity != null:
			return identity.persistent_id
	return &""
