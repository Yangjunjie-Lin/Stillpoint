extends RefCounted


func run() -> bool:
	var actor := EconomicTestHelper.make_blacksmith_actor(&"npc:unpaid", 10)
	var state := EconomicTestHelper.worksite_state(19)
	var energy_before := actor.energy.current_energy
	var result := WorkService.new().perform(
		actor,
		ResourceRegistry.get_job(&"job:blacksmith"),
		ResourceRegistry.get_worksite(&"worksite:town_smithy"),
		state,
		20,
		&"unpaid-test",
		1,
	)
	var ok: bool = not bool(result.get("success", true)) and str(result.get("code", "")) == "insufficient_payroll"
	ok = ok and state.payroll_balance == 19 and actor.wallet.get_balance() == 10
	ok = ok and actor.energy.current_energy == energy_before
	ok = ok and actor.skills.get_points(&"smithing") == 0.0
	actor.free()
	if not ok:
		push_error("insufficient payroll caused a partial work mutation")
	return ok
