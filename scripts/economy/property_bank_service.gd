class_name PropertyBankService
extends Node
## Owns the player's private-home deed, wallet, bank account, and custodial stores.
## Runtime ownership is scoped by principal ID; authored HouseDefinition resources
## describe plans and values but never hold mutable ownership or inventory state.

signal property_state_changed

const SECTION_VERSION := 1
const OWNER_PRINCIPAL_ID := &"base:player/main"
const DEFAULT_HOUSE_ID := &"building:player_farmhouse"
const STATUS_OWNED := &"owned"
const STATUS_REPOSSESSED := &"repossessed"
const HOME_STORAGE_MODE := &"home"
const BANK_STORAGE_MODE := &"bank"
const DEFAULT_WALLET_BALANCE := 500
const DEFAULT_BANK_SLOTS := 120
const DEFAULT_HOME_SLOTS := 48
const DEFAULT_ASSESSED_VALUE := 2500

@export_range(86400, 31536000, 86400) var offline_reclaim_seconds: int = 30 * 86400

var owner_principal_id: StringName = OWNER_PRINCIPAL_ID
var wallet_balance: int = DEFAULT_WALLET_BALANCE
var bank_balance: int = 0
var house_status: StringName = STATUS_OWNED
var current_house_id: StringName = DEFAULT_HOUSE_ID
var repossessed_house_id: StringName = &""
var last_seen_unix: int = 0
var last_compensation: int = 0
var repossession_count: int = 0
var home_storage: InventoryComponent
var bank_storage: InventoryComponent
var _session: WorldSession


func _ready() -> void:
	_ensure_stores()


func setup(session: WorldSession) -> void:
	_session = session
	_ensure_stores()


func reset_defaults() -> void:
	_ensure_stores()
	owner_principal_id = OWNER_PRINCIPAL_ID
	wallet_balance = DEFAULT_WALLET_BALANCE
	bank_balance = 0
	house_status = STATUS_OWNED
	current_house_id = DEFAULT_HOUSE_ID
	repossessed_house_id = &""
	last_seen_unix = 0
	last_compensation = 0
	repossession_count = 0
	_set_home_capacity(_house_storage_slots(current_house_id))
	home_storage.from_dict({})
	bank_storage.from_dict({})
	_emit_changed()


func has_active_house() -> bool:
	return house_status == STATUS_OWNED and current_house_id != &""


func get_active_house() -> HouseDefinition:
	return ResourceRegistry.get_house(current_house_id) if has_active_house() else null


func get_repossessed_house() -> HouseDefinition:
	return ResourceRegistry.get_house(repossessed_house_id)


func get_storage(mode: StringName) -> InventoryComponent:
	_ensure_stores()
	return home_storage if mode == HOME_STORAGE_MODE else bank_storage


func store_from_player(
	player_inventory: InventoryComponent,
	mode: StringName,
	player_slot_index: int,
	amount: int = -1,
) -> int:
	if mode == HOME_STORAGE_MODE and not has_active_house():
		return 0
	var moved := InventoryTransferService.transfer_slot(
		player_inventory, get_storage(mode), player_slot_index, amount
	)
	if moved > 0:
		_emit_changed()
	return moved


func withdraw_to_player(
	player_inventory: InventoryComponent,
	mode: StringName,
	storage_slot_index: int,
	amount: int = -1,
) -> int:
	if mode == HOME_STORAGE_MODE and not has_active_house():
		return 0
	var moved := InventoryTransferService.transfer_slot(
		get_storage(mode), player_inventory, storage_slot_index, amount
	)
	if moved > 0:
		_emit_changed()
	return moved


func deposit(amount: int) -> int:
	var moved := clampi(amount, 0, wallet_balance)
	if moved <= 0:
		return 0
	wallet_balance -= moved
	bank_balance += moved
	_emit_changed()
	return moved


func withdraw(amount: int) -> int:
	var moved := clampi(amount, 0, bank_balance)
	if moved <= 0:
		return 0
	bank_balance -= moved
	wallet_balance += moved
	_emit_changed()
	return moved


func construct_house(plan_id: StringName) -> bool:
	if has_active_house():
		return false
	var plan := ResourceRegistry.get_house(plan_id)
	if plan == null or not plan.player_selectable:
		return false
	if not _charge(plan.construction_cost):
		return false
	house_status = STATUS_OWNED
	current_house_id = plan.id
	repossessed_house_id = &""
	last_compensation = 0
	_set_home_capacity(plan.private_storage_slots)
	_emit_changed()
	return true


func buy_back_repossessed_house() -> bool:
	if has_active_house() or repossessed_house_id == &"":
		return false
	var plan := ResourceRegistry.get_house(repossessed_house_id)
	if plan == null or not plan.player_selectable:
		return false
	var price := _assessed_value(plan.id)
	if not _charge(price):
		return false
	house_status = STATUS_OWNED
	current_house_id = plan.id
	repossessed_house_id = &""
	last_compensation = 0
	_set_home_capacity(plan.private_storage_slots)
	_emit_changed()
	return true


func process_offline_elapsed(elapsed_seconds: int) -> bool:
	if elapsed_seconds < offline_reclaim_seconds or not has_active_house():
		return false
	return _repossess_active_house()


func capture_save_data(now_unix: int = -1) -> Dictionary:
	_ensure_stores()
	last_seen_unix = _now_unix() if now_unix < 0 else maxi(0, now_unix)
	return {
		"section_version": SECTION_VERSION,
		"owner_principal_id": String(owner_principal_id),
		"wallet_balance": wallet_balance,
		"bank_balance": bank_balance,
		"house_status": String(house_status),
		"current_house_id": String(current_house_id),
		"repossessed_house_id": String(repossessed_house_id),
		"last_seen_unix": last_seen_unix,
		"last_compensation": last_compensation,
		"repossession_count": repossession_count,
		"offline_reclaim_seconds": offline_reclaim_seconds,
		"home_storage": home_storage.to_dict(),
		"bank_storage": bank_storage.to_dict(),
	}


func restore_save_data(data: Dictionary, now_unix: int = -1) -> bool:
	_ensure_stores()
	if data.is_empty():
		reset_defaults()
		last_seen_unix = _now_unix() if now_unix < 0 else maxi(0, now_unix)
		return true
	var version := int(data.get("section_version", SECTION_VERSION))
	if version < 0 or version > SECTION_VERSION:
		return false
	# Save data cannot redirect this single-player account to another principal.
	owner_principal_id = OWNER_PRINCIPAL_ID
	wallet_balance = maxi(0, int(data.get("wallet_balance", DEFAULT_WALLET_BALANCE)))
	bank_balance = maxi(0, int(data.get("bank_balance", 0)))
	var restored_status := StringName(str(data.get("house_status", String(STATUS_OWNED))))
	house_status = restored_status if restored_status in [STATUS_OWNED, STATUS_REPOSSESSED] else STATUS_OWNED
	current_house_id = StringName(str(data.get("current_house_id", String(DEFAULT_HOUSE_ID))))
	repossessed_house_id = StringName(str(data.get("repossessed_house_id", "")))
	if house_status == STATUS_OWNED and not _is_valid_plan(current_house_id):
		current_house_id = DEFAULT_HOUSE_ID
	if house_status == STATUS_REPOSSESSED and not _is_valid_plan(repossessed_house_id):
		repossessed_house_id = DEFAULT_HOUSE_ID
	last_seen_unix = maxi(0, int(data.get("last_seen_unix", 0)))
	last_compensation = maxi(0, int(data.get("last_compensation", 0)))
	repossession_count = maxi(0, int(data.get("repossession_count", 0)))
	_set_home_capacity(_house_storage_slots(current_house_id))
	home_storage.from_dict(_dictionary(data.get("home_storage", {})))
	bank_storage.from_dict(_dictionary(data.get("bank_storage", {})))
	var now := _now_unix() if now_unix < 0 else maxi(0, now_unix)
	if last_seen_unix > 0 and now > last_seen_unix:
		process_offline_elapsed(now - last_seen_unix)
	last_seen_unix = now
	_emit_changed()
	return true


func get_status_summary() -> String:
	if has_active_house():
		var house := get_active_house()
		return "Residence: %s (owner: %s)" % [
			house.display_name if house != null else String(current_house_id),
			String(owner_principal_id),
		]
	var previous := get_repossessed_house()
	return "Residence reclaimed after inactivity. Previous deed: %s" % (
		previous.display_name if previous != null else String(repossessed_house_id)
	)


func get_total_funds() -> int:
	return wallet_balance + bank_balance


func get_buyback_price() -> int:
	return _assessed_value(repossessed_house_id) if repossessed_house_id != &"" else 0


func _repossess_active_house() -> bool:
	_ensure_stores()
	if not InventoryTransferService.transfer_all(home_storage, bank_storage):
		push_warning("PropertyBankService: bank vault has insufficient custody capacity")
		return false
	var previous_id := current_house_id
	var compensation := _assessed_value(previous_id)
	bank_balance += compensation
	house_status = STATUS_REPOSSESSED
	repossessed_house_id = previous_id
	current_house_id = &""
	last_compensation = compensation
	repossession_count += 1
	_emit_changed()
	return true


func _charge(amount: int) -> bool:
	var cost := maxi(0, amount)
	if get_total_funds() < cost:
		return false
	var from_bank := mini(bank_balance, cost)
	bank_balance -= from_bank
	wallet_balance -= cost - from_bank
	return true


func _assessed_value(house_id: StringName) -> int:
	var definition := ResourceRegistry.get_house(house_id)
	return maxi(0, definition.assessed_value) if definition != null else DEFAULT_ASSESSED_VALUE


func _house_storage_slots(house_id: StringName) -> int:
	var definition := ResourceRegistry.get_house(house_id)
	return maxi(1, definition.private_storage_slots) if (
		definition != null and definition.private_storage_slots > 0
	) else DEFAULT_HOME_SLOTS


func _is_valid_plan(house_id: StringName) -> bool:
	var definition := ResourceRegistry.get_house(house_id)
	return definition != null and definition.player_selectable


func _set_home_capacity(capacity: int) -> void:
	_ensure_stores()
	home_storage.slot_count = maxi(1, capacity)
	# get_slot forces allocation without changing existing stacks.
	home_storage.get_slot(home_storage.slot_count - 1)


func _ensure_stores() -> void:
	if home_storage == null:
		home_storage = get_node_or_null("HomeStorage") as InventoryComponent
	if bank_storage == null:
		bank_storage = get_node_or_null("BankStorage") as InventoryComponent
	if home_storage == null:
		home_storage = InventoryComponent.new()
		home_storage.name = "HomeStorage"
		home_storage.slot_count = DEFAULT_HOME_SLOTS
		add_child(home_storage)
	if bank_storage == null:
		bank_storage = InventoryComponent.new()
		bank_storage.name = "BankStorage"
		bank_storage.slot_count = DEFAULT_BANK_SLOTS
		add_child(bank_storage)
	bank_storage.slot_count = maxi(DEFAULT_BANK_SLOTS, bank_storage.slot_count)
	home_storage.get_slot(home_storage.slot_count - 1)
	bank_storage.get_slot(bank_storage.slot_count - 1)


func _emit_changed() -> void:
	property_state_changed.emit()


func _now_unix() -> int:
	return int(Time.get_unix_time_from_system())


func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}
