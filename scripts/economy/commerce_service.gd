class_name CommerceService
extends RefCounted
## Stateless transactional shop and forge operations for any actor inventory and
## funds capability (personal WalletComponent or player bank-plus-wallet adapter).
##
## Every inventory mutation is first completed on a private simulation. Funds
## are changed only after that simulation succeeds, so insufficient currency,
## materials, or backpack capacity leaves both sides untouched.

const CODE_PURCHASED := &"purchased"
const CODE_SOLD := &"sold"
const CODE_FORGED := &"forged"


func buy(
	shop_id: StringName,
	offer_id: StringName,
	purchase_count: int,
	inventory: InventoryComponent,
	funds_service: Object,
	transaction_context: Dictionary = {},
) -> Dictionary:
	if purchase_count <= 0 or inventory == null or funds_service == null:
		return _result(false, &"invalid_request")
	var shop := ResourceRegistry.get_shop(shop_id)
	if shop == null:
		return _result(false, &"unknown_shop")
	var offer := shop.get_offer(offer_id)
	if offer == null or not offer.is_valid():
		return _result(false, &"unknown_offer")
	var item := ResourceRegistry.get_item(offer.item_id)
	if item == null:
		return _result(false, &"unknown_item")
	var item_quantity := offer.quantity_per_purchase * purchase_count
	var total_price := offer.resolved_unit_price(item) * item_quantity
	if item_quantity <= 0 or total_price <= 0:
		return _result(false, &"invalid_price")
	if funds_service.get_total_funds() < total_price:
		return _result(false, &"insufficient_funds")
	var simulation := _duplicate_inventory(inventory)
	if simulation.add_item(item.id, item_quantity) != item_quantity:
		simulation.free()
		return _result(false, &"inventory_full")
	var next_inventory := simulation.to_dict()
	simulation.free()
	var context := transaction_context.duplicate(true)
	context["reason"] = "purchase"
	context["shop_id"] = String(shop.id)
	if not _spend_funds(funds_service, total_price, context):
		return _result(false, &"insufficient_funds")
	inventory.from_dict(next_inventory)
	return _result(true, CODE_PURCHASED, {
		"shop_id": String(shop.id),
		"offer_id": String(offer.id),
		"item_id": String(item.id),
		"quantity": item_quantity,
		"funds_delta": -total_price,
	})


func sell(
	shop_id: StringName,
	item_id: StringName,
	quantity: int,
	inventory: InventoryComponent,
	funds_service: Object,
	transaction_context: Dictionary = {},
) -> Dictionary:
	if quantity <= 0 or inventory == null or funds_service == null:
		return _result(false, &"invalid_request")
	var shop := ResourceRegistry.get_shop(shop_id)
	if shop == null or not shop.buys_from_player:
		return _result(false, &"shop_does_not_buy")
	var item := ResourceRegistry.get_item(item_id)
	if item == null:
		return _result(false, &"unknown_item")
	if item.sell_price <= 0:
		return _result(false, &"not_sellable")
	if inventory.count_item(item.id) < quantity:
		return _result(false, &"insufficient_items")
	var simulation := _duplicate_inventory(inventory)
	if simulation.remove_item(item.id, quantity) != quantity:
		simulation.free()
		return _result(false, &"insufficient_items")
	var next_inventory := simulation.to_dict()
	simulation.free()
	var proceeds := item.sell_price * quantity
	var context := transaction_context.duplicate(true)
	context["reason"] = "sale"
	context["shop_id"] = String(shop.id)
	if not _credit_wallet(funds_service, proceeds, context):
		return _result(false, &"funds_service_unavailable")
	inventory.from_dict(next_inventory)
	return _result(true, CODE_SOLD, {
		"shop_id": String(shop.id),
		"item_id": String(item.id),
		"quantity": quantity,
		"funds_delta": proceeds,
	})


func forge(
	recipe_id: StringName,
	craft_count: int,
	inventory: InventoryComponent,
	funds_service: Object,
	player_level: int = 1,
	transaction_context: Dictionary = {},
) -> Dictionary:
	if craft_count <= 0 or inventory == null or funds_service == null:
		return _result(false, &"invalid_request")
	var recipe := ResourceRegistry.get_forge_recipe(recipe_id)
	if recipe == null or not recipe.is_valid():
		return _result(false, &"unknown_recipe")
	if ResourceRegistry.get_item(recipe.output_item_id) == null:
		return _result(false, &"unknown_output_item")
	if player_level < recipe.required_level:
		return _result(false, &"level_too_low")
	var ingredients := recipe.normalized_ingredients()
	for item_id in ingredients.keys():
		var required := int(ingredients[item_id]) * craft_count
		if inventory.count_item(item_id) < required:
			return _result(false, &"insufficient_materials", {"missing_item_id": String(item_id)})
	var total_fee := recipe.service_fee * craft_count
	if funds_service.get_total_funds() < total_fee:
		return _result(false, &"insufficient_funds")
	var simulation := _duplicate_inventory(inventory)
	for item_id in ingredients.keys():
		var required := int(ingredients[item_id]) * craft_count
		if simulation.remove_item(item_id, required) != required:
			simulation.free()
			return _result(false, &"insufficient_materials", {"missing_item_id": String(item_id)})
	var output_quantity := recipe.output_quantity * craft_count
	if simulation.add_item(recipe.output_item_id, output_quantity) != output_quantity:
		simulation.free()
		return _result(false, &"inventory_full")
	var next_inventory := simulation.to_dict()
	simulation.free()
	var context := transaction_context.duplicate(true)
	context["reason"] = "forge_fee"
	if total_fee > 0 and not _spend_funds(funds_service, total_fee, context):
		return _result(false, &"insufficient_funds")
	inventory.from_dict(next_inventory)
	return _result(true, CODE_FORGED, {
		"recipe_id": String(recipe.id),
		"item_id": String(recipe.output_item_id),
		"quantity": output_quantity,
		"funds_delta": -total_fee,
	})


func _duplicate_inventory(inventory: InventoryComponent) -> InventoryComponent:
	var duplicate := InventoryComponent.new()
	duplicate.slot_count = inventory.slot_count
	duplicate.from_dict(inventory.to_dict())
	return duplicate


func _spend_funds(service: Object, amount: int, context: Dictionary = {}) -> bool:
	if amount <= 0:
		return true
	if service is WalletComponent:
		return (service as WalletComponent).debit(amount, context)
	if not service.has_method(&"spend_funds"):
		return false
	return _transaction_result_succeeded(service.call(&"spend_funds", amount), amount)


func _credit_wallet(service: Object, amount: int, context: Dictionary = {}) -> bool:
	if amount <= 0:
		return true
	if service is WalletComponent:
		return (service as WalletComponent).credit(amount, context)
	if not service.has_method(&"credit_wallet"):
		return false
	return _transaction_result_succeeded(service.call(&"credit_wallet", amount), amount)


func _transaction_result_succeeded(value: Variant, expected_amount: int) -> bool:
	if value is bool:
		return bool(value)
	if value is int or value is float:
		return int(value) == expected_amount
	return false


func _result(success: bool, code: StringName, details: Dictionary = {}) -> Dictionary:
	var result := {"success": success, "code": String(code)}
	result.merge(details, true)
	return result
