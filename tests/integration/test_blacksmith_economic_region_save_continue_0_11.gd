extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	var actor := _blacksmith(world)
	if actor == null:
		world.free()
		return false
	actor.set_physics_process(false)
	var worksite := ResourceRegistry.get_worksite(&"worksite:town_smithy")
	actor.global_position = world.actor_economy_service.find_worksite_marker(worksite).global_position
	var schedule := actor.get_node_or_null("ScheduleComponent") as ScheduleComponent
	if schedule != null:
		schedule.tick()
	var planner := NPCEconomicPlanner.new()
	var ok: bool = true
	for _step in 10:
		var proposal := planner.propose_next(actor)
		if proposal == null:
			ok = false
			break
		var result := world.submit_intent(proposal)
		if not result.is_valid:
			ok = false
			break
		if actor.equipment.get_equipped_item(ItemDefinition.EquipSlot.WEAPON) == &"improved_forge_hammer" \
				and proposal.intent is WorkIntent:
			break
	var expected := _state(world, actor)

	world.region_service.enter_region(&"base:farmland")
	world.region_service.enter_region(&"base:town")
	var region_restored := _blacksmith(world)
	if region_restored == null:
		world.free()
		return false
	region_restored.set_physics_process(false)
	var region_state := _state(world, region_restored)
	if region_state != expected:
		push_error("region economic mismatch expected=%s actual=%s" % [JSON.stringify(expected), JSON.stringify(region_state)])
	ok = ok and region_state == expected
	ok = ok and world.save_world_state()
	world.free()

	GameManager.resume_requested = true
	var continued := WorldTestHelper.boot_world(tree)
	var continued_actor := _blacksmith(continued)
	if continued_actor == null:
		continued.free()
		GameManager.resume_requested = false
		return false
	continued_actor.set_physics_process(false)
	var continued_state := _state(continued, continued_actor)
	if continued_state != expected:
		push_error("continue economic mismatch expected=%s actual=%s" % [JSON.stringify(expected), JSON.stringify(continued_state)])
	ok = ok and continued_state == expected
	var before_replay := _state(continued, continued_actor)
	var contract := continued_actor.employment.current_contract
	var replay := IntentProposal.new(
		&"restart-sequence-replay",
		IntentProposal.SourceKind.DETERMINISTIC_AI,
		continued_actor.get_persistent_actor_id(),
		WorkIntent.new(
			continued_actor.get_persistent_actor_id(),
			contract.job_id,
			contract.worksite_id,
			continued_actor.employment.economic_sequence,
		),
	)
	var replay_result := continued.submit_intent(replay)
	ok = ok and not replay_result.is_valid and replay_result.code == &"economic_sequence_replayed"
	ok = ok and _state(continued, continued_actor) == before_replay
	continued.free()
	GameManager.resume_requested = false
	if not ok:
		push_error("blacksmith region reload or Save/Continue economic persistence failed")
	return ok


func _state(world: WorldSession, actor: NPCController) -> Dictionary:
	var state := world.actor_economy_service.get_worksite_state(&"worksite:town_smithy")
	return {
		"wallet": actor.wallet.get_balance(),
		"inventory": actor.inventory.to_dict(),
		"equipment": actor.equipment.to_dict(),
		"employment": actor.employment.to_dict(),
		"skills": actor.skills.to_dict(),
		"energy": actor.energy.to_dict(),
		"payroll": state.payroll_balance,
		"work_units": state.lifetime_work_units,
	}


func _blacksmith(world: WorldSession) -> NPCController:
	for entity in world.entity_repository.get_loaded_entities_in_region(&"base:town"):
		if entity is NPCController and (entity as NPCController).character_id == &"blacksmith":
			return entity as NPCController
	return null
