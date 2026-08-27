class_name EconomicTransactionCoordinator
extends RefCounted
## Bounded staged commit/rollback for actor-business money and item transfers.
## This is single-process coordination, not database ACID.


static func commit_trade(
	plan: EconomicTransactionPlan,
	actor_inventory: InventoryComponent,
	funds_service: Object,
	business: BusinessRuntimeState,
	actor_sequence_owner: EmploymentComponent = null,
	transaction_context: Dictionary = {},
) -> Dictionary:
	if plan == null or actor_inventory == null or funds_service == null or business == null:
		return _result(false, &"transaction_unavailable")
	if not plan.money_is_conserved() or not plan.items_are_conserved():
		return _result(false, &"conservation_violation")
	var authorization := _authorize(plan, business, actor_sequence_owner)
	if not authorization.is_empty():
		return authorization

	var actor_next := _simulate_inventory(actor_inventory, plan.actor_inventory_deltas)
	if actor_next.is_empty():
		return _result(false, &"actor_inventory_commit_failed")
	var business_next := _simulate_inventory(business.inventory, plan.business_inventory_deltas)
	if business_next.is_empty():
		return _result(false, &"business_inventory_commit_failed")
	if plan.actor_money_delta < 0 and _total_funds(funds_service) < -plan.actor_money_delta:
		return _result(false, &"insufficient_funds")
	if plan.actor_money_delta > 0 and not _can_credit_funds(funds_service, plan.actor_money_delta):
		return _result(false, &"wallet_capacity")
	if plan.business_money_delta < 0 and not business.can_spend(-plan.business_money_delta):
		return _result(false, &"business_insufficient_funds")
	if plan.business_money_delta > 0 and not business.can_credit(plan.business_money_delta):
		return _result(false, &"business_treasury_capacity")

	# Capture every live participant before final authorization.
	var actor_inventory_before := actor_inventory.to_dict()
	var funds_before := _capture_funds(funds_service)
	var business_before := business.to_dict()
	var actor_sequence_before := actor_sequence_owner.to_dict() if actor_sequence_owner != null else {}
	authorization = _authorize(plan, business, actor_sequence_owner)
	if not authorization.is_empty():
		return authorization

	var committed := _apply_actor_money(funds_service, plan.actor_money_delta, transaction_context)
	if committed:
		committed = _apply_business_money(business, plan.business_money_delta, plan.transaction_kind)
	if committed:
		actor_inventory.from_dict(actor_next)
		business.inventory.from_dict(business_next)
	if committed and plan.expected_actor_sequence >= 0:
		committed = actor_sequence_owner != null \
			and actor_sequence_owner.commit_sequence(plan.expected_actor_sequence)
	if committed and plan.expected_business_sequence >= 0:
		committed = business.commit_sequence(plan.expected_business_sequence)
	if not committed:
		actor_inventory.from_dict(actor_inventory_before)
		_restore_funds(funds_service, funds_before)
		business.restore_from_dict(business_before, business.inventory.slot_count)
		if actor_sequence_owner != null:
			actor_sequence_owner.from_dict(actor_sequence_before)
		return _result(false, &"transaction_commit_failed")

	business.note_stock_changed(plan.transaction_kind)
	if plan.transaction_kind == &"purchase":
		for item_id in plan.business_inventory_deltas.keys():
			var delta := int(plan.business_inventory_deltas[item_id])
			if delta < 0:
				business.note_sale(StringName(str(item_id)), -delta)
	elif plan.transaction_kind == &"sale":
		for item_id in plan.business_inventory_deltas.keys():
			business.note_supply(maxi(0, int(plan.business_inventory_deltas[item_id])))
	return _result(true, &"committed")


static func _authorize(
	plan: EconomicTransactionPlan,
	business: BusinessRuntimeState,
	actor_sequence_owner: EmploymentComponent,
) -> Dictionary:
	if plan.business_id != &"" and business.business_id != plan.business_id:
		return _result(false, &"business_mismatch")
	if plan.expected_price_revision >= 0 and business.price_revision != plan.expected_price_revision:
		return _result(false, &"stale_quote")
	if plan.expected_business_sequence >= 0 \
			and not business.can_commit_sequence(plan.expected_business_sequence):
		return _result(false, &"business_sequence_replayed")
	if plan.expected_actor_sequence >= 0 \
			and (actor_sequence_owner == null \
			or not actor_sequence_owner.can_commit_sequence(plan.expected_actor_sequence)):
		return _result(false, &"economic_sequence_replayed")
	return {}


static func _simulate_inventory(inventory: InventoryComponent, deltas: Dictionary) -> Dictionary:
	var simulation := InventoryComponent.new()
	simulation.slot_count = inventory.slot_count
	simulation.from_dict(inventory.to_dict())
	var ids := deltas.keys()
	ids.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
	for raw_id in ids:
		var item_id := StringName(str(raw_id))
		var delta := int(deltas[raw_id])
		if delta < 0 and simulation.remove_item(item_id, -delta) != -delta:
			simulation.free()
			return {}
		if delta > 0 and simulation.add_item(item_id, delta) != delta:
			simulation.free()
			return {}
	var result := simulation.to_dict()
	simulation.free()
	return result


static func _capture_funds(service: Object) -> Dictionary:
	if service is WalletComponent:
		return (service as WalletComponent).to_dict()
	if service.has_method(&"capture_transaction_state"):
		var state: Variant = service.call(&"capture_transaction_state")
		return state.duplicate(true) if state is Dictionary else {}
	return {}


static func _restore_funds(service: Object, state: Dictionary) -> bool:
	if service is WalletComponent:
		return (service as WalletComponent).from_dict(state)
	if service.has_method(&"restore_transaction_state"):
		return bool(service.call(&"restore_transaction_state", state))
	return false


static func _total_funds(service: Object) -> int:
	if service is WalletComponent:
		return (service as WalletComponent).get_total_funds()
	return int(service.call(&"get_total_funds")) if service.has_method(&"get_total_funds") else 0


static func _can_credit_funds(service: Object, amount: int) -> bool:
	if service is WalletComponent:
		return (service as WalletComponent).get_balance() <= 1000000000 - amount
	if service.has_method(&"can_credit_wallet"):
		return bool(service.call(&"can_credit_wallet", amount))
	return service.has_method(&"credit_wallet")


static func _apply_actor_money(service: Object, delta: int, context: Dictionary) -> bool:
	if delta == 0:
		return true
	if delta < 0:
		if service is WalletComponent:
			return (service as WalletComponent).debit(-delta, context)
		return bool(service.call(&"spend_funds", -delta, context)) \
			if service.has_method(&"spend_funds") else false
	if service is WalletComponent:
		return (service as WalletComponent).credit(delta, context)
	if not service.has_method(&"credit_wallet"):
		return false
	var result: Variant = service.call(&"credit_wallet", delta, context)
	return bool(result) if result is bool else int(result) == delta


static func _apply_business_money(
	business: BusinessRuntimeState,
	delta: int,
	kind: StringName,
) -> bool:
	if delta == 0:
		return true
	if delta > 0:
		return business.credit(delta, &"sale_revenue" if kind == &"purchase" else &"revenue")
	return business.debit(-delta, &"actor_buyback" if kind == &"sale" else &"expense")


static func _result(success: bool, code: StringName) -> Dictionary:
	return {"success": success, "code": String(code)}
