extends RefCounted


func run() -> bool:
	var actor := EconomicTestHelper.make_blacksmith_actor(&"npc:payroll", 10)
	var state := EconomicTestHelper.worksite_state()
	var business := EconomicTestHelper.business_state(100)
	var result := WorkService.new().perform(
		actor,
		ResourceRegistry.get_job(&"job:blacksmith"),
		ResourceRegistry.get_worksite(&"worksite:town_smithy"),
		state,
		business,
		20,
		&"payroll-test",
		1,
		1,
	)
	var ok: bool = bool(result.get("success", false))
	ok = ok and business.get_treasury_balance() == 80 and actor.wallet.get_balance() == 30
	ok = ok and business.get_treasury_balance() + actor.wallet.get_balance() == 110
	var work := result.get("result") as WorkResult
	ok = ok and work != null and work.skill_after > work.skill_before and work.energy_spent == 8.0
	actor.free()
	business.free()
	if not ok:
		push_error("paid work failed payroll conservation or progression")
	return ok
