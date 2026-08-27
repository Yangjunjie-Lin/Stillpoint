class_name BusinessRuntimeState
extends Node
## One persistent mutable cash and inventory owner for an authored business.

signal state_changed(reason: StringName)

const SECTION_VERSION := 1
const MAX_BALANCE := 1000000000
const MAX_RECENT_ITEM_SUMMARIES := 64
const DEMAND_DECAY_PER_DAY := 0.75

var business_id: StringName = &""
var inventory: InventoryComponent
var economic_sequence: int = 0
var price_revision: int = 0
var recent_demand_score: float = 0.0
var recent_sales_summary: Dictionary = {}
var lifetime_revenue: int = 0
var lifetime_expenses: int = 0
var last_processed_day: int = 1
var _treasury_balance: int = 0


func _init() -> void:
	inventory = InventoryComponent.new()
	inventory.name = "BusinessInventory"
	add_child(inventory)


func initialize(definition: BusinessDefinition) -> bool:
	if definition == null or not definition.is_valid():
		return false
	business_id = definition.id
	inventory.slot_count = definition.inventory_slots
	inventory.from_dict({})
	for raw_id in definition.initial_inventory.keys():
		var item_id := StringName(str(raw_id))
		var quantity := maxi(0, int(definition.initial_inventory[raw_id]))
		if quantity > 0 and inventory.add_item(item_id, quantity) != quantity:
			return false
	return restore_treasury(definition.initial_treasury)


func get_treasury_balance() -> int:
	return _treasury_balance


func can_spend(amount: int) -> bool:
	return amount >= 0 and _treasury_balance >= amount


func can_credit(amount: int) -> bool:
	return amount >= 0 and _treasury_balance <= MAX_BALANCE - amount


func debit(amount: int, reason: StringName = &"expense") -> bool:
	if amount <= 0 or not can_spend(amount):
		return false
	_treasury_balance -= amount
	if reason != &"rollback":
		lifetime_expenses += amount
	state_changed.emit(reason)
	return true


func credit(amount: int, reason: StringName = &"revenue") -> bool:
	if amount <= 0 or not can_credit(amount):
		return false
	_treasury_balance += amount
	if reason != &"rollback":
		lifetime_revenue += amount
	state_changed.emit(reason)
	return true


func restore_treasury(amount: int) -> bool:
	if amount < 0 or amount > MAX_BALANCE:
		return false
	_treasury_balance = amount
	return true


func expected_next_sequence() -> int:
	return economic_sequence + 1


func can_commit_sequence(sequence: int) -> bool:
	return sequence == expected_next_sequence()


func commit_sequence(sequence: int) -> bool:
	if not can_commit_sequence(sequence):
		return false
	economic_sequence = sequence
	return true


func note_stock_changed(reason: StringName = &"stock_changed") -> void:
	price_revision += 1
	state_changed.emit(reason)


func note_sale(item_id: StringName, quantity: int) -> void:
	if item_id == &"" or quantity <= 0:
		return
	recent_demand_score = clampf(recent_demand_score * 0.8 + float(quantity) * 0.2, -1.0, 1.0)
	var key := String(item_id)
	recent_sales_summary[key] = maxi(0, int(recent_sales_summary.get(key, 0))) + quantity
	_trim_sales_summary()


func note_supply(quantity: int) -> void:
	if quantity > 0:
		recent_demand_score = clampf(recent_demand_score - minf(0.25, float(quantity) * 0.02), -1.0, 1.0)


func advance_to_day(day: int) -> void:
	var target_day := maxi(1, day)
	var elapsed := target_day - last_processed_day
	if elapsed <= 0:
		return
	var previous := recent_demand_score
	recent_demand_score = clampf(
		recent_demand_score * pow(DEMAND_DECAY_PER_DAY, float(elapsed)), -1.0, 1.0
	)
	last_processed_day = target_day
	if not is_equal_approx(previous, recent_demand_score):
		price_revision += 1
		state_changed.emit(&"demand_decay")


func to_dict() -> Dictionary:
	return {
		"section_version": SECTION_VERSION,
		"business_id": String(business_id),
		"treasury_balance": _treasury_balance,
		"inventory_slots": inventory.slot_count,
		"inventory": inventory.to_dict(),
		"economic_sequence": economic_sequence,
		"price_revision": price_revision,
		"recent_demand_score": recent_demand_score,
		"recent_sales_summary": recent_sales_summary.duplicate(true),
		"lifetime_revenue": lifetime_revenue,
		"lifetime_expenses": lifetime_expenses,
		"last_processed_day": last_processed_day,
	}


func restore_from_dict(data: Dictionary, fallback_slots: int = 24) -> bool:
	var version := int(data.get("section_version", SECTION_VERSION))
	if version < 0 or version > SECTION_VERSION:
		return false
	business_id = StringName(str(data.get("business_id", business_id)))
	if not restore_treasury(int(data.get("treasury_balance", 0))):
		return false
	inventory.slot_count = clampi(int(data.get("inventory_slots", fallback_slots)), 1, 1000)
	var raw_inventory: Variant = data.get("inventory", {})
	inventory.from_dict(raw_inventory as Dictionary if raw_inventory is Dictionary else {})
	economic_sequence = maxi(0, int(data.get("economic_sequence", 0)))
	price_revision = maxi(0, int(data.get("price_revision", 0)))
	recent_demand_score = clampf(float(data.get("recent_demand_score", 0.0)), -1.0, 1.0)
	recent_sales_summary.clear()
	var raw_sales: Variant = data.get("recent_sales_summary", {})
	if raw_sales is Dictionary:
		for raw_id in (raw_sales as Dictionary).keys():
			if recent_sales_summary.size() >= MAX_RECENT_ITEM_SUMMARIES:
				break
			var item_id := str(raw_id).strip_edges().left(96)
			if not item_id.is_empty():
				recent_sales_summary[item_id] = maxi(0, int((raw_sales as Dictionary)[raw_id]))
	lifetime_revenue = maxi(0, int(data.get("lifetime_revenue", 0)))
	lifetime_expenses = maxi(0, int(data.get("lifetime_expenses", 0)))
	last_processed_day = maxi(1, int(data.get("last_processed_day", 1)))
	return true


func _trim_sales_summary() -> void:
	while recent_sales_summary.size() > MAX_RECENT_ITEM_SUMMARIES:
		var keys := recent_sales_summary.keys()
		keys.sort_custom(func(a: Variant, b: Variant) -> bool:
			var a_count := int(recent_sales_summary.get(a, 0))
			var b_count := int(recent_sales_summary.get(b, 0))
			return a_count < b_count if a_count != b_count else str(a) < str(b)
		)
		recent_sales_summary.erase(keys[0])
