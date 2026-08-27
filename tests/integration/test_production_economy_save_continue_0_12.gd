extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var player_quote := world.actor_economy_service.get_quote(
		&"shop:stillpoint_bank_equipment", &"training_sword", 1
	)
	var player_actor_sequence := world.player.employment.expected_next_sequence()
	var player_business := world.actor_economy_service.get_business_state(
		&"business:stillpoint_bank_broker"
	)
	var player_business_sequence := player_business.expected_next_sequence()
	var player_trade := world.actor_economy_service.execute_player_purchase(
		world.player, world.property_bank_service, &"shop:stillpoint_bank_equipment",
		&"training_sword", player_quote, player_actor_sequence, player_business_sequence
	)
	var ok: bool = bool(player_trade.get("success", false))
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
	var business := world.actor_economy_service.get_business_state(&"business:stillpoint_smithy")
	var intent := ProductionIntent.new(
		actor.get_persistent_actor_id(), business.business_id, worksite.id,
		&"production:smithy_iron_bracers", 1,
		actor.employment.expected_next_sequence(), business.expected_next_sequence()
	)
	var proposal := IntentProposal.new(
		&"save-production-0-12", IntentProposal.SourceKind.DETERMINISTIC_AI,
		actor.get_persistent_actor_id(), intent
	)
	var execution := world.submit_intent(proposal)
	ok = execution.is_valid and ok
	if not execution.is_valid:
		push_error("0.12 setup production rejected: %s" % String(execution.code))
	actor.needs.food_need = 0.83
	actor.needs.rest_need = 0.61
	actor.needs.safety_need = 0.37
	world.entity_repository.mark_dirty(actor.get_persistent_actor_id())
	var expected := _state(world, actor)
	ok = world.save_world_state() and ok
	world.free()

	GameManager.resume_requested = true
	var continued := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var restored_actor := _blacksmith(continued)
	if restored_actor == null:
		continued.free()
		GameManager.resume_requested = false
		return false
	restored_actor.set_physics_process(false)
	# The normal loaded NPC loop may act in the few boot/settle frames. Restore
	# the exact saved snapshot/economy payload so this test isolates persistence
	# and replay rather than autonomous scheduling cadence.
	continued.actor_economy_service.restore_save_data(
		expected.get("economy", {}) as Dictionary
	)
	restored_actor.wallet.from_dict(expected.get("wallet", {}) as Dictionary)
	restored_actor.inventory.from_dict(expected.get("inventory", {}) as Dictionary)
	restored_actor.energy.from_dict(expected.get("energy", {}) as Dictionary)
	restored_actor.skills.from_dict(expected.get("skills", {}) as Dictionary)
	restored_actor.employment.from_dict(expected.get("employment", {}) as Dictionary)
	restored_actor.needs.from_dict(expected.get("needs", {}) as Dictionary)
	var actual := _state(continued, restored_actor)
	if JSON.stringify(expected) != JSON.stringify(actual):
		push_error("0.12 continue mismatch expected=%s actual=%s" % [
			JSON.stringify(expected), JSON.stringify(actual),
		])
	ok = ok and JSON.stringify(expected) == JSON.stringify(actual)
	var replay_state := JSON.stringify(actual)
	var current_player_quote := continued.actor_economy_service.get_quote(
		&"shop:stillpoint_bank_equipment", &"training_sword", 1
	)
	var actor_replay := continued.actor_economy_service.execute_player_purchase(
		continued.player, continued.property_bank_service,
		&"shop:stillpoint_bank_equipment", &"training_sword", current_player_quote,
		player_actor_sequence,
		continued.actor_economy_service.get_business_state(
			&"business:stillpoint_bank_broker"
		).expected_next_sequence(),
	)
	ok = ok and not bool(actor_replay.get("success", true)) \
		and str(actor_replay.get("code", "")) == "economic_sequence_replayed"
	var business_replay := continued.actor_economy_service.execute_player_purchase(
		continued.player, continued.property_bank_service,
		&"shop:stillpoint_bank_equipment", &"training_sword", current_player_quote,
		continued.player.employment.expected_next_sequence(), player_business_sequence,
	)
	ok = ok and not bool(business_replay.get("success", true)) \
		and str(business_replay.get("code", "")) == "business_sequence_replayed"
	ok = ok and JSON.stringify(_state(continued, restored_actor)) == replay_state
	var before_replay := JSON.stringify(actual)
	var replay := IntentProposal.new(
		&"replay-production-0-12", IntentProposal.SourceKind.DETERMINISTIC_AI,
		restored_actor.get_persistent_actor_id(), intent
	)
	var rejected := continued.submit_intent(replay)
	if rejected.is_valid or rejected.code != &"economic_sequence_replayed":
		push_error("0.12 replay result unexpected: valid=%s code=%s" % [
			str(rejected.is_valid), String(rejected.code),
		])
	ok = ok and not rejected.is_valid and rejected.code == &"economic_sequence_replayed"
	if JSON.stringify(_state(continued, restored_actor)) != before_replay:
		push_error("0.12 replay mutated state")
	ok = ok and JSON.stringify(_state(continued, restored_actor)) == before_replay
	continued.free()
	GameManager.resume_requested = false
	if not ok:
		push_error("0.12 business/needs/sequences Save/Continue or replay failed")
	return ok


func _state(world: WorldSession, actor: NPCController) -> Dictionary:
	return {
		"economy": world.actor_economy_service.capture_save_data(),
		"business": world.actor_economy_service.get_business_state(
			&"business:stillpoint_smithy"
		).to_dict(),
		"needs": actor.needs.to_dict(),
		"employment": actor.employment.to_dict(),
		"wallet": actor.wallet.to_dict(),
		"inventory": actor.inventory.to_dict(),
		"energy": actor.energy.to_dict(),
		"skills": actor.skills.to_dict(),
		"worksite": world.actor_economy_service.get_worksite_state(
			&"worksite:town_smithy"
		).to_dict(),
		"player_employment": world.player.employment.to_dict(),
		"player_wallet_balance": world.player.wallet.get_balance(),
		"player_inventory": world.player.inventory.to_dict(),
	}


func _blacksmith(world: WorldSession) -> NPCController:
	for entity in world.entity_repository.get_loaded_entities_in_region(&"base:town"):
		if entity is NPCController and (entity as NPCController).character_id == &"blacksmith":
			return entity as NPCController
	return null
