extends RefCounted


func run() -> bool:
	var actor := EconomicTestHelper.make_blacksmith_actor(&"npc:producer", 10)
	var worksite := EconomicTestHelper.worksite_state()
	var business := EconomicTestHelper.business_state(100)
	var recipe := ResourceRegistry.get_production_recipe(&"production:smithy_iron_bracers")
	var service := ProductionService.new()
	var ore_before := business.inventory.count_item(&"iron_ore")
	var output_before := business.inventory.count_item(&"iron_bracers")
	var money_before := actor.wallet.get_balance() + business.get_treasury_balance()
	var result := service.perform(
		actor, ResourceRegistry.get_job(&"job:blacksmith"),
		ResourceRegistry.get_worksite(&"worksite:town_smithy"), worksite,
		business, recipe, 1, 25, &"production-test", 1, 1
	)
	var ok: bool = bool(result.get("success", false))
	ok = ok and business.inventory.count_item(&"iron_ore") == ore_before - 2
	ok = ok and business.inventory.count_item(&"iron_bracers") == output_before + 1
	ok = ok and actor.wallet.get_balance() + business.get_treasury_balance() == money_before
	ok = ok and business.get_treasury_balance() == 75 and actor.wallet.get_balance() == 35
	ok = ok and actor.energy.current_energy == 92.0
	ok = ok and actor.skills.get_points(&"smithing") > 0.0

	var buyer_inventory := InventoryComponent.new()
	var buyer_wallet := WalletComponent.new()
	buyer_wallet.restore_balance(1000)
	var commerce := CommerceService.new()
	var quote := commerce.quote(
		&"shop:stillpoint_blacksmith_equipment", &"iron_bracers", business
	)
	var sale := commerce.buy(
		&"shop:stillpoint_blacksmith_equipment", &"iron_bracers", 1,
		buyer_inventory, buyer_wallet, business, quote
	)
	ok = ok and bool(sale.get("success", false))
	var revenue_balance := business.get_treasury_balance()
	var second := service.perform(
		actor, ResourceRegistry.get_job(&"job:blacksmith"),
		ResourceRegistry.get_worksite(&"worksite:town_smithy"), worksite,
		business, recipe, 1, 25, &"production-test-2", 2, 3
	)
	ok = ok and bool(second.get("success", false))
	ok = ok and business.get_treasury_balance() == revenue_balance - 25

	var failed_before := {
		"actor": actor.wallet.to_dict(),
		"energy": actor.energy.to_dict(),
		"skills": actor.skills.to_dict(),
		"employment": actor.employment.to_dict(),
		"business": business.to_dict(),
		"worksite": worksite.to_dict(),
	}
	business.inventory.remove_item(&"iron_ore", business.inventory.count_item(&"iron_ore"))
	# Snapshot the deliberate test setup, then prove the failed production is inert.
	failed_before["business"] = business.to_dict()
	var failed := service.perform(
		actor, ResourceRegistry.get_job(&"job:blacksmith"),
		ResourceRegistry.get_worksite(&"worksite:town_smithy"), worksite,
		business, recipe, 1, 25, &"missing-input", 3, 4
	)
	ok = ok and not bool(failed.get("success", true)) \
		and str(failed.get("code", "")) == "insufficient_inputs"
	ok = ok and JSON.stringify(failed_before) == JSON.stringify({
		"actor": actor.wallet.to_dict(),
		"energy": actor.energy.to_dict(),
		"skills": actor.skills.to_dict(),
		"employment": actor.employment.to_dict(),
		"business": business.to_dict(),
		"worksite": worksite.to_dict(),
	})
	buyer_inventory.free()
	buyer_wallet.free()
	actor.free()
	business.free()
	if not ok:
		push_error("production input/output/wage conservation or revenue feedback failed")
	return ok
