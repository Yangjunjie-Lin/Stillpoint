extends RefCounted

const BANK_SHOP := &"shop:stillpoint_bank_equipment"
const SMITH_SHOP := &"shop:stillpoint_blacksmith_equipment"
const RECIPE := &"forge:greywake_iron_sword"


func run() -> bool:
	var commerce := CommerceService.new()
	var ok := _buy_success(commerce)
	ok = _buy_failures_leave_state_unchanged(commerce) and ok
	ok = _sell_permissions_and_success(commerce) and ok
	ok = _forge_success(commerce) and ok
	ok = _forge_failures_leave_state_unchanged(commerce) and ok
	if not ok:
		push_error("commerce purchase, sale, forging, or transactional rollback failed")
	return ok


func _buy_success(commerce: CommerceService) -> bool:
	var inventory := _inventory(4)
	var funds := _funds(100, 100)
	var before_total := funds.get_total_assets()
	var result := commerce.buy(BANK_SHOP, &"training_sword", 1, inventory, funds)
	var price := ResourceRegistry.get_item(&"training_sword").buy_price
	var ok := bool(result.get("success", false))
	ok = ok and String(result.get("code", "")) == "purchased"
	ok = ok and inventory.count_item(&"training_sword") == 1
	ok = ok and funds.get_total_assets() == before_total - price
	ok = ok and funds.bank_balance == 0 and funds.wallet_balance == 200 - price
	_free_pair(inventory, funds)
	return ok


func _buy_failures_leave_state_unchanged(commerce: CommerceService) -> bool:
	var inventory := _inventory(2)
	var funds := _funds(139, 0)
	var before := _snapshot(inventory, funds)
	var result := commerce.buy(BANK_SHOP, &"training_sword", 1, inventory, funds)
	var ok := not bool(result.get("success", true))
	ok = ok and String(result.get("code", "")) == "insufficient_funds"
	ok = ok and _snapshot(inventory, funds) == before
	_free_pair(inventory, funds)

	# A full backpack may not be partially changed and may not be charged.
	inventory = _inventory(1)
	funds = _funds(500, 250)
	ok = inventory.add_item(&"training_sword", 1) == 1 and ok
	before = _snapshot(inventory, funds)
	result = commerce.buy(BANK_SHOP, &"padded_vest", 1, inventory, funds)
	ok = ok and not bool(result.get("success", true))
	ok = ok and String(result.get("code", "")) == "inventory_full"
	ok = ok and _snapshot(inventory, funds) == before
	_free_pair(inventory, funds)
	return ok


func _sell_permissions_and_success(commerce: CommerceService) -> bool:
	var inventory := _inventory(3)
	var funds := _funds(25, 40)
	var ok := inventory.add_item(&"training_sword", 1) == 1
	var before := _snapshot(inventory, funds)
	var rejected := commerce.sell(SMITH_SHOP, &"training_sword", 1, inventory, funds)
	ok = ok and not bool(rejected.get("success", true))
	ok = ok and String(rejected.get("code", "")) == "shop_does_not_buy"
	ok = ok and _snapshot(inventory, funds) == before
	var missing := commerce.sell(BANK_SHOP, &"training_sword", 2, inventory, funds)
	ok = ok and not bool(missing.get("success", true))
	ok = ok and String(missing.get("code", "")) == "insufficient_items"
	ok = ok and _snapshot(inventory, funds) == before

	var sold := commerce.sell(BANK_SHOP, &"training_sword", 1, inventory, funds)
	var proceeds := ResourceRegistry.get_item(&"training_sword").sell_price
	ok = ok and bool(sold.get("success", false))
	ok = ok and String(sold.get("code", "")) == "sold"
	ok = ok and inventory.count_item(&"training_sword") == 0
	ok = ok and funds.wallet_balance == 25 + proceeds
	ok = ok and funds.bank_balance == 40
	_free_pair(inventory, funds)
	return ok


func _forge_success(commerce: CommerceService) -> bool:
	var inventory := _inventory(4)
	var funds := _funds(100, 50)
	var ok := inventory.add_item(&"iron_ore", 3) == 3
	ok = inventory.add_item(&"training_sword", 1) == 1 and ok
	var result := commerce.forge(RECIPE, 1, inventory, funds, 2)
	ok = ok and bool(result.get("success", false))
	ok = ok and String(result.get("code", "")) == "forged"
	ok = ok and inventory.count_item(&"iron_ore") == 0
	ok = ok and inventory.count_item(&"training_sword") == 0
	ok = ok and inventory.count_item(&"forged_iron_sword") == 1
	ok = ok and funds.bank_balance == 0 and funds.wallet_balance == 65
	_free_pair(inventory, funds)
	return ok


func _forge_failures_leave_state_unchanged(commerce: CommerceService) -> bool:
	var ok := true
	var failure_cases: Array[Dictionary] = [
		{"code": "level_too_low", "ore": 3, "sword": 1, "wallet": 200, "level": 1},
		{"code": "insufficient_materials", "ore": 2, "sword": 1, "wallet": 200, "level": 2},
		{"code": "insufficient_funds", "ore": 3, "sword": 1, "wallet": 84, "level": 2},
	]
	for failure in failure_cases:
		var inventory := _inventory(4)
		var funds := _funds(int(failure["wallet"]), 0)
		ok = inventory.add_item(&"iron_ore", int(failure["ore"])) == int(failure["ore"]) and ok
		ok = inventory.add_item(&"training_sword", int(failure["sword"])) == int(failure["sword"]) and ok
		var before := _snapshot(inventory, funds)
		var result := commerce.forge(RECIPE, 1, inventory, funds, int(failure["level"]))
		ok = ok and not bool(result.get("success", true))
		ok = ok and String(result.get("code", "")) == String(failure["code"])
		ok = ok and _snapshot(inventory, funds) == before
		_free_pair(inventory, funds)

	# A test-only recipe isolates the capacity edge: it consumes three from a
	# stack of four ore but produces a non-stackable sword. One ore remains in
	# the sole slot, so the real inventory/funds must remain untouched.
	var capacity_recipe := ForgeRecipeDefinition.new()
	capacity_recipe.id = &"forge:test_inventory_full"
	capacity_recipe.display_name = "Capacity rollback recipe"
	capacity_recipe.building_id = &"building:stillpoint_blacksmith"
	capacity_recipe.ingredients = {&"iron_ore": 3}
	capacity_recipe.output_item_id = &"forged_iron_sword"
	capacity_recipe.output_quantity = 1
	capacity_recipe.service_fee = 85
	capacity_recipe.required_level = 2
	ResourceRegistry.register_forge_recipe(capacity_recipe)
	var full_inventory := _inventory(1)
	var full_funds := _funds(200, 0)
	ok = full_inventory.add_item(&"iron_ore", 4) == 4 and ok
	var full_before := _snapshot(full_inventory, full_funds)
	var full_result := commerce.forge(
		capacity_recipe.id, 1, full_inventory, full_funds, 2
	)
	ok = ok and not bool(full_result.get("success", true))
	ok = ok and String(full_result.get("code", "")) == "inventory_full"
	ok = ok and _snapshot(full_inventory, full_funds) == full_before
	_free_pair(full_inventory, full_funds)
	return ok


func _inventory(slots: int) -> InventoryComponent:
	var inventory := InventoryComponent.new()
	inventory.slot_count = slots
	return inventory


func _funds(wallet: int, bank: int) -> PropertyBankService:
	var service := PropertyBankService.new()
	service.reset_defaults()
	service.wallet_balance = wallet
	service.bank_balance = bank
	return service


func _snapshot(inventory: InventoryComponent, funds: PropertyBankService) -> Dictionary:
	return {
		"inventory": inventory.to_dict(),
		"wallet": funds.wallet_balance,
		"bank": funds.bank_balance,
		"home": funds.home_cash_balance,
		"principal": funds.investment_principal,
		"earnings": funds.investment_earnings,
	}


func _free_pair(inventory: InventoryComponent, funds: PropertyBankService) -> void:
	inventory.free()
	funds.free()
