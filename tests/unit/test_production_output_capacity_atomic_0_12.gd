extends RefCounted


func run() -> bool:
	var actor := EconomicTestHelper.make_blacksmith_actor(&"npc:capacity", 10)
	var business := EconomicTestHelper.business_state(100)
	business.inventory.slot_count = 1
	business.inventory.from_dict({
		"slots": [{"item_id": "iron_ore", "quantity": 4}],
	})
	var worksite := EconomicTestHelper.worksite_state()
	var before := {
		"wallet": actor.wallet.to_dict(),
		"energy": actor.energy.to_dict(),
		"skills": actor.skills.to_dict(),
		"employment": actor.employment.to_dict(),
		"business": business.to_dict(),
		"worksite": worksite.to_dict(),
	}
	var result := ProductionService.new().perform(
		actor, ResourceRegistry.get_job(&"job:blacksmith"),
		ResourceRegistry.get_worksite(&"worksite:town_smithy"), worksite, business,
		ResourceRegistry.get_production_recipe(&"production:smithy_iron_bracers"),
		1, 25, &"capacity-test", 1, 1
	)
	var ok: bool = not bool(result.get("success", true)) \
		and str(result.get("code", "")) == "output_inventory_full"
	ok = ok and JSON.stringify(before) == JSON.stringify({
		"wallet": actor.wallet.to_dict(),
		"energy": actor.energy.to_dict(),
		"skills": actor.skills.to_dict(),
		"employment": actor.employment.to_dict(),
		"business": business.to_dict(),
		"worksite": worksite.to_dict(),
	})
	ok = ok and business.get_treasury_balance() >= 0
	actor.free()
	business.free()
	if not ok:
		push_error("full production output inventory caused a partial mutation")
	return ok
