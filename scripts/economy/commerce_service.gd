class_name CommerceService
extends RefCounted
## Deterministic quotes and staged two-party business commerce.

const CODE_PURCHASED := &"purchased"
const CODE_SOLD := &"sold"
const CODE_FORGED := &"forged"
const MIN_PRICE := 1
const MAX_PRICE := 1000000


func quote(
	shop_id: StringName,
	offer_id: StringName,
	business: BusinessRuntimeState,
	purchase_count: int = 1,
) -> CommerceQuote:
	var result := CommerceQuote.new()
	result.shop_id = shop_id
	result.offer_id = offer_id
	result.quoted_world_day = WorldTimeService.day
	result.quoted_world_hour = WorldTimeService.hour
	if purchase_count <= 0 or business == null:
		return result
	var shop := ResourceRegistry.get_shop(shop_id)
	var offer := shop.get_offer(offer_id) if shop != null else null
	var item := ResourceRegistry.get_item(offer.item_id) if offer != null else null
	var definition := ResourceRegistry.get_business(business.business_id)
	if shop == null or offer == null or item == null or definition == null \
			or definition.shop_id != shop.id:
		return result
	var quantity := offer.quantity_per_purchase * purchase_count
	result.business_id = business.business_id
	result.item_id = item.id
	result.available_quantity = business.inventory.count_item(item.id)
	result.unit_price = scarcity_unit_price(
		offer.resolved_unit_price(item),
		result.available_quantity,
		definition.target_quantity(item.id),
		business.recent_demand_score,
	)
	result.total_price = _safe_total(result.unit_price, quantity)
	result.price_revision = business.price_revision
	return result


func quote_buyback(
	shop_id: StringName,
	item_id: StringName,
	business: BusinessRuntimeState,
	quantity: int = 1,
) -> CommerceQuote:
	var result := CommerceQuote.new()
	result.shop_id = shop_id
	result.offer_id = item_id
	result.item_id = item_id
	result.quoted_world_day = WorldTimeService.day
	result.quoted_world_hour = WorldTimeService.hour
	var shop := ResourceRegistry.get_shop(shop_id)
	var item := ResourceRegistry.get_item(item_id)
	var definition := ResourceRegistry.get_business(business.business_id) if business != null else null
	if quantity <= 0 or shop == null or not shop.buys_from_player or item == null \
			or definition == null or definition.shop_id != shop.id \
			or not _business_accepts_item(definition, item):
		return result
	var stock := business.inventory.count_item(item.id)
	var target := maxi(1, definition.target_quantity(item.id))
	var stock_ratio := float(stock) / float(target)
	var multiplier := clampf(
		1.25 - 0.25 * stock_ratio + 0.05 * business.recent_demand_score, 0.5, 1.5
	)
	result.business_id = business.business_id
	result.available_quantity = stock
	result.unit_price = clampi(
		int(round(float(item.sell_price) * multiplier)), MIN_PRICE, MAX_PRICE
	) if item.sell_price > 0 else 0
	result.total_price = _safe_total(result.unit_price, quantity)
	result.price_revision = business.price_revision
	return result


func scarcity_unit_price(
	base_price: int,
	current_stock: int,
	target_stock: int,
	demand_score: float = 0.0,
) -> int:
	if base_price <= 0:
		return 0
	var target := maxi(1, target_stock)
	var stock_ratio := float(maxi(0, current_stock)) / float(target)
	var scarcity_multiplier := clampf(1.5 - 0.5 * stock_ratio, 0.5, 3.0)
	var demand_multiplier := clampf(
		1.0 + 0.15 * clampf(demand_score, -1.0, 1.0), 0.85, 1.15
	)
	return clampi(
		int(round(float(base_price) * scarcity_multiplier * demand_multiplier)),
		MIN_PRICE,
		MAX_PRICE,
	)


func buy(
	shop_id: StringName,
	offer_id: StringName,
	purchase_count: int,
	inventory: InventoryComponent,
	funds_service: Object,
	business: BusinessRuntimeState,
	validated_quote: CommerceQuote = null,
	actor_sequence_owner: EmploymentComponent = null,
	expected_actor_sequence: int = -1,
	transaction_context: Dictionary = {},
	expected_business_sequence: int = -1,
) -> Dictionary:
	if purchase_count <= 0 or inventory == null or funds_service == null or business == null:
		return _result(false, &"invalid_request")
	var shop := ResourceRegistry.get_shop(shop_id)
	var offer := shop.get_offer(offer_id) if shop != null else null
	if shop == null:
		return _result(false, &"unknown_shop")
	if offer == null or not offer.is_valid():
		return _result(false, &"unknown_offer")
	var item := ResourceRegistry.get_item(offer.item_id)
	if item == null:
		return _result(false, &"unknown_item")
	var current_quote := quote(shop_id, offer_id, business, purchase_count)
	var supplied := validated_quote if validated_quote != null else current_quote
	if not _quote_matches(supplied, current_quote):
		return _result(false, &"stale_quote")
	var item_quantity := offer.quantity_per_purchase * purchase_count
	if current_quote.available_quantity < item_quantity:
		return _result(false, &"out_of_stock")
	if current_quote.total_price <= 0:
		return _result(false, &"invalid_price")
	if int(funds_service.call(&"get_total_funds")) < current_quote.total_price:
		return _result(false, &"insufficient_funds")
	if not inventory.can_add_item(item.id, item_quantity):
		return _result(false, &"inventory_full")
	var plan := EconomicTransactionPlan.new()
	plan.transaction_kind = &"purchase"
	plan.actor_id = StringName(str(transaction_context.get("actor_id", "")))
	plan.business_id = business.business_id
	plan.actor_money_delta = -current_quote.total_price
	plan.business_money_delta = current_quote.total_price
	plan.actor_inventory_deltas = {item.id: item_quantity}
	plan.business_inventory_deltas = {item.id: -item_quantity}
	plan.expected_actor_sequence = expected_actor_sequence
	plan.expected_business_sequence = business.expected_next_sequence() \
		if expected_business_sequence < 0 else expected_business_sequence
	plan.expected_price_revision = current_quote.price_revision
	var commit := EconomicTransactionCoordinator.commit_trade(
		plan, inventory, funds_service, business, actor_sequence_owner, _context(
			transaction_context, &"purchase", shop.id, business.business_id
		)
	)
	if not bool(commit.get("success", false)):
		return commit
	return _result(true, CODE_PURCHASED, {
		"business_id": String(business.business_id),
		"shop_id": String(shop.id),
		"offer_id": String(offer.id),
		"item_id": String(item.id),
		"quantity": item_quantity,
		"unit_price": current_quote.unit_price,
		"total_price": current_quote.total_price,
		"funds_delta": -current_quote.total_price,
		"price_revision": current_quote.price_revision,
		"business_sequence": business.economic_sequence,
	})


func sell(
	shop_id: StringName,
	item_id: StringName,
	quantity: int,
	inventory: InventoryComponent,
	funds_service: Object,
	business: BusinessRuntimeState,
	validated_quote: CommerceQuote = null,
	actor_sequence_owner: EmploymentComponent = null,
	expected_actor_sequence: int = -1,
	transaction_context: Dictionary = {},
	expected_business_sequence: int = -1,
) -> Dictionary:
	if quantity <= 0 or inventory == null or funds_service == null or business == null:
		return _result(false, &"invalid_request")
	var shop := ResourceRegistry.get_shop(shop_id)
	if shop == null or not shop.buys_from_player:
		return _result(false, &"shop_does_not_buy")
	var item := ResourceRegistry.get_item(item_id)
	var definition := ResourceRegistry.get_business(business.business_id)
	if item == null:
		return _result(false, &"unknown_item")
	if item.sell_price <= 0 or definition == null or not _business_accepts_item(definition, item):
		return _result(false, &"not_sellable")
	if inventory.count_item(item.id) < quantity:
		return _result(false, &"insufficient_items")
	if not business.inventory.can_add_item(item.id, quantity):
		return _result(false, &"business_inventory_full")
	var current_quote := quote_buyback(shop_id, item_id, business, quantity)
	var supplied := validated_quote if validated_quote != null else current_quote
	if not _quote_matches(supplied, current_quote):
		return _result(false, &"stale_quote")
	var proceeds := current_quote.total_price
	if proceeds <= 0:
		return _result(false, &"invalid_price")
	if not business.can_spend(proceeds) \
			or business.get_treasury_balance() - proceeds < definition.reserve_cash:
		return _result(false, &"business_insufficient_funds")
	var plan := EconomicTransactionPlan.new()
	plan.transaction_kind = &"sale"
	plan.actor_id = StringName(str(transaction_context.get("actor_id", "")))
	plan.business_id = business.business_id
	plan.actor_money_delta = proceeds
	plan.business_money_delta = -proceeds
	plan.actor_inventory_deltas = {item.id: -quantity}
	plan.business_inventory_deltas = {item.id: quantity}
	plan.expected_actor_sequence = expected_actor_sequence
	plan.expected_business_sequence = business.expected_next_sequence() \
		if expected_business_sequence < 0 else expected_business_sequence
	plan.expected_price_revision = current_quote.price_revision
	var commit := EconomicTransactionCoordinator.commit_trade(
		plan, inventory, funds_service, business, actor_sequence_owner, _context(
			transaction_context, &"sale", shop.id, business.business_id
		)
	)
	if not bool(commit.get("success", false)):
		return commit
	return _result(true, CODE_SOLD, {
		"business_id": String(business.business_id),
		"shop_id": String(shop.id),
		"item_id": String(item.id),
		"quantity": quantity,
		"unit_price": current_quote.unit_price,
		"total_price": proceeds,
		"funds_delta": proceeds,
		"price_revision": current_quote.price_revision,
		"business_sequence": business.economic_sequence,
	})


func forge(
	recipe_id: StringName,
	craft_count: int,
	inventory: InventoryComponent,
	funds_service: Object,
	player_level: int,
	business: BusinessRuntimeState,
	expected_business_sequence: int = -1,
	transaction_context: Dictionary = {},
	actor_sequence_owner: EmploymentComponent = null,
	expected_actor_sequence: int = -1,
) -> Dictionary:
	if craft_count <= 0 or inventory == null or funds_service == null or business == null:
		return _result(false, &"invalid_request")
	var recipe := ResourceRegistry.get_forge_recipe(recipe_id)
	if recipe == null or not recipe.is_valid():
		return _result(false, &"unknown_recipe")
	if player_level < recipe.required_level:
		return _result(false, &"level_too_low")
	var definition := ResourceRegistry.get_business(business.business_id)
	if definition == null or definition.building_id != recipe.building_id:
		return _result(false, &"business_mismatch")
	var simulation := _duplicate_inventory(inventory)
	for item_id in recipe.normalized_ingredients().keys():
		var required := recipe.ingredient_quantity(item_id) * craft_count
		if simulation.remove_item(item_id, required) != required:
			simulation.free()
			return _result(false, &"insufficient_materials", {
				"missing_item_id": String(item_id),
			})
	var output_quantity := recipe.output_quantity * craft_count
	if simulation.add_item(recipe.output_item_id, output_quantity) != output_quantity:
		simulation.free()
		return _result(false, &"inventory_full")
	var next_inventory := simulation.to_dict()
	simulation.free()
	var total_fee := recipe.service_fee * craft_count
	if int(funds_service.call(&"get_total_funds")) < total_fee:
		return _result(false, &"insufficient_funds")
	if not business.can_credit(total_fee):
		return _result(false, &"business_treasury_capacity")
	var sequence := business.expected_next_sequence() \
		if expected_business_sequence < 0 else expected_business_sequence
	if not business.can_commit_sequence(sequence):
		return _result(false, &"business_sequence_replayed")
	if expected_actor_sequence >= 0 and (actor_sequence_owner == null \
			or not actor_sequence_owner.can_commit_sequence(expected_actor_sequence)):
		return _result(false, &"economic_sequence_replayed")
	var inventory_before := inventory.to_dict()
	var funds_before: Dictionary = funds_service.to_dict() if funds_service is WalletComponent \
		else funds_service.call(&"capture_transaction_state")
	var business_before := business.to_dict()
	var actor_sequence_before := actor_sequence_owner.to_dict() \
		if actor_sequence_owner != null else {}
	if not business.can_commit_sequence(sequence) or expected_actor_sequence >= 0 \
			and (actor_sequence_owner == null \
			or not actor_sequence_owner.can_commit_sequence(expected_actor_sequence)):
		return _result(false, &"sequence_replayed")
	var context := _context(
		transaction_context, &"forge_fee", definition.shop_id, business.business_id
	)
	var committed := total_fee == 0 or _spend_funds(funds_service, total_fee, context)
	if committed and total_fee > 0:
		committed = business.credit(total_fee, &"forge_service_revenue")
	if committed:
		inventory.from_dict(next_inventory)
		if expected_actor_sequence >= 0:
			committed = actor_sequence_owner.commit_sequence(expected_actor_sequence)
		if committed:
			committed = business.commit_sequence(sequence)
	if not committed:
		inventory.from_dict(inventory_before)
		if funds_service is WalletComponent:
			(funds_service as WalletComponent).from_dict(funds_before)
		else:
			funds_service.call(&"restore_transaction_state", funds_before)
		business.restore_from_dict(business_before, business.inventory.slot_count)
		if actor_sequence_owner != null:
			actor_sequence_owner.from_dict(actor_sequence_before)
		return _result(false, &"transaction_commit_failed")
	return _result(true, CODE_FORGED, {
		"business_id": String(business.business_id),
		"recipe_id": String(recipe.id),
		"item_id": String(recipe.output_item_id),
		"quantity": output_quantity,
		"funds_delta": -total_fee,
		"business_sequence": business.economic_sequence,
	})


func _quote_matches(supplied: CommerceQuote, current: CommerceQuote) -> bool:
	return supplied != null and current != null \
		and supplied.business_id == current.business_id \
		and supplied.shop_id == current.shop_id \
		and supplied.offer_id == current.offer_id \
		and supplied.item_id == current.item_id \
		and supplied.unit_price == current.unit_price \
		and supplied.total_price == current.total_price \
		and supplied.price_revision == current.price_revision


func _business_accepts_item(definition: BusinessDefinition, item: ItemDefinition) -> bool:
	return definition != null and item != null \
		and definition.buy_categories.has(_category_name(item.resolved_inventory_category()))


func _category_name(category: int) -> StringName:
	match category:
		ItemDefinition.InventoryCategory.TOOLS:
			return &"tools"
		ItemDefinition.InventoryCategory.WEAPONS:
			return &"weapons"
		ItemDefinition.InventoryCategory.WEARABLES:
			return &"wearables"
		ItemDefinition.InventoryCategory.CONSUMABLES:
			return &"consumables"
		ItemDefinition.InventoryCategory.MATERIALS:
			return &"materials"
		ItemDefinition.InventoryCategory.SKILL_BOOKS:
			return &"skill_books"
		ItemDefinition.InventoryCategory.QUEST_ITEMS:
			return &"quest_items"
	return &"other"


func _safe_total(unit_price: int, quantity: int) -> int:
	if unit_price <= 0 or quantity <= 0 or unit_price > 1000000000 / quantity:
		return 0
	return unit_price * quantity


func _duplicate_inventory(inventory: InventoryComponent) -> InventoryComponent:
	var duplicate := InventoryComponent.new()
	duplicate.slot_count = inventory.slot_count
	duplicate.from_dict(inventory.to_dict())
	return duplicate


func _spend_funds(service: Object, amount: int, context: Dictionary) -> bool:
	if amount <= 0:
		return true
	if service is WalletComponent:
		return (service as WalletComponent).debit(amount, context)
	return bool(service.call(&"spend_funds", amount, context)) \
		if service.has_method(&"spend_funds") else false


func _context(
	base: Dictionary,
	reason: StringName,
	shop_id: StringName,
	business_id: StringName,
) -> Dictionary:
	var result := base.duplicate(true)
	result["reason"] = String(reason)
	result["shop_id"] = String(shop_id)
	result["counterparty_id"] = String(business_id)
	result["world_day"] = WorldTimeService.day
	result["world_hour"] = WorldTimeService.hour
	return result


func _result(success: bool, code: StringName, details: Dictionary = {}) -> Dictionary:
	var result := {"success": success, "code": String(code)}
	result.merge(details, true)
	return result
