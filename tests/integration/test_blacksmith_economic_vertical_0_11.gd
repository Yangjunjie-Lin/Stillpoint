extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var actor := _blacksmith(world)
	if actor == null:
		world.free()
		push_error("blacksmith vertical test could not find actor")
		return false
	actor.set_physics_process(false)
	var actor_id := actor.get_persistent_actor_id()
	var job := ResourceRegistry.get_job(&"job:blacksmith")
	var worksite := ResourceRegistry.get_worksite(&"worksite:town_smithy")
	var marker := world.actor_economy_service.find_worksite_marker(worksite)
	actor.global_position = marker.global_position
	var schedule := actor.get_node_or_null("ScheduleComponent") as ScheduleComponent
	if schedule != null:
		schedule.tick()
	var state := world.actor_economy_service.get_worksite_state(worksite.id)
	var business := world.actor_economy_service.get_business_state(&"business:stillpoint_smithy")
	var total_before: int = actor.wallet.get_balance() + business.get_treasury_balance()
	var skill_before := actor.skills.get_points(&"smithing")
	var starter_output := -1.0
	var improved_output := -1.0
	var saw_purchase := false
	var saw_equip := false
	var planner := NPCEconomicPlanner.new()
	var ok: bool = actor_id != &"" and actor.wallet != null and actor.inventory != null \
		and actor.equipment != null and actor.employment != null
	ok = ok and actor.employment.current_contract != null
	for _step in 10:
		var proposal := planner.propose_next(actor, world.actor_economy_service)
		if proposal == null:
			ok = false
			break
		var result := world.submit_intent(proposal)
		ok = ok and result.is_valid
		if not result.is_valid:
			break
		if proposal.intent is ProductionIntent:
			var last := actor.employment.last_work_result
			if last.get("tool_id", "") == "starter_forge_hammer":
				starter_output = float(last.get("work_units", -1.0))
			elif last.get("tool_id", "") == "improved_forge_hammer":
				improved_output = float(last.get("work_units", -1.0))
				break
		elif proposal.intent is PurchaseIntent:
			saw_purchase = true
		elif proposal.intent is EquipIntent:
			saw_equip = true
	ok = ok and saw_purchase and saw_equip
	ok = ok and starter_output > 0.0 and improved_output > starter_output
	ok = ok and actor.skills.get_points(job.work_skill_id) > skill_before
	ok = ok and actor.equipment.get_equipped_item(ItemDefinition.EquipSlot.WEAPON) == &"improved_forge_hammer"
	ok = ok and actor.wallet.get_balance() + business.get_treasury_balance() == total_before
	var snapshot := EntitySnapshot.new()
	snapshot.capture_from_node(actor)
	ok = ok and snapshot.component_states.has("wallet") and snapshot.component_states.has("employment")
	var saved_sequence := actor.employment.economic_sequence
	var saved_wallet := actor.wallet.get_balance()
	var saved_treasury: int = business.get_treasury_balance()
	var replay := IntentProposal.new(
		&"replay-old-sequence",
		IntentProposal.SourceKind.DETERMINISTIC_AI,
		actor_id,
		WorkIntent.new(actor_id, job.id, worksite.id, saved_sequence),
	)
	var replay_result := world.submit_intent(replay)
	ok = ok and not replay_result.is_valid and replay_result.code == &"economic_sequence_replayed"
	ok = ok and actor.wallet.get_balance() == saved_wallet \
		and business.get_treasury_balance() == saved_treasury
	world.free()
	if not ok:
		push_error("blacksmith work/wage/skill/purchase/equip/output/replay vertical failed")
	return ok


func _blacksmith(world: WorldSession) -> NPCController:
	for entity in world.entity_repository.get_loaded_entities_in_region(&"base:town"):
		if entity is NPCController and (entity as NPCController).character_id == &"blacksmith":
			return entity as NPCController
	return null
