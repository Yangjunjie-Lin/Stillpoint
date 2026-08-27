extends RefCounted


func run() -> bool:
	var service := WorkService.new()
	var job := ResourceRegistry.get_job(&"job:blacksmith")
	var worksite := ResourceRegistry.get_worksite(&"worksite:town_smithy")
	var base := EconomicTestHelper.make_blacksmith_actor()
	var first := service.calculate_preview(base, job, worksite)
	var second := service.calculate_preview(base, job, worksite)
	var ok: bool = first == second

	var skilled := EconomicTestHelper.make_blacksmith_actor(&"npc:skilled")
	skilled.skills.set_proficiency_points(&"smithing", 60.0)
	var skilled_output := service.calculate_preview(skilled, job, worksite)
	ok = ok and skilled_output.work_units > first.work_units

	var improved := EconomicTestHelper.make_blacksmith_actor(&"npc:improved", 10, &"improved_forge_hammer")
	var improved_output := service.calculate_preview(improved, job, worksite)
	ok = ok and improved_output.work_units > first.work_units

	var fatigued := EconomicTestHelper.make_blacksmith_actor(&"npc:fatigued")
	fatigued.energy.current_energy = 10.0
	var fatigued_output := service.calculate_preview(fatigued, job, worksite)
	ok = ok and fatigued_output.work_units < first.work_units

	var better_site := WorkSiteDefinition.new()
	better_site.id = &"worksite:better"
	better_site.worksite_type = &"smithy"
	better_site.region_id = &"base:town"
	better_site.work_marker_id = &"work"
	better_site.workplace_efficiency = worksite.workplace_efficiency + 0.25
	var better_output := service.calculate_preview(base, job, better_site)
	ok = ok and better_output.work_units > first.work_units
	base.free()
	skilled.free()
	improved.free()
	fatigued.free()
	if not ok:
		push_error("deterministic work formula or monotonic factors failed")
	return ok
