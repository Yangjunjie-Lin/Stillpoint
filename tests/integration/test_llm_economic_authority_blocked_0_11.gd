extends RefCounted


func run() -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	var world := WorldTestHelper.boot_world(tree)
	await WorldTestHelper.await_frames(tree, 3)
	var actor := _blacksmith(world)
	if actor == null:
		world.free()
		push_error("LLM economic authority test could not find blacksmith")
		return false
	actor.set_physics_process(false)
	var marker := world.actor_economy_service.find_worksite_marker(
		ResourceRegistry.get_worksite(&"worksite:town_smithy")
	)
	actor.global_position = marker.global_position
	var contract := actor.employment.current_contract
	var sequence := actor.employment.expected_next_sequence()
	var wallet_before := actor.wallet.get_balance()
	var skill_before := actor.skills.get_points(&"smithing")
	var payroll_before := world.actor_economy_service.get_worksite_state(contract.worksite_id).payroll_balance
	var forged := IntentProposal.new(
		&"llm-forged-wage",
		IntentProposal.SourceKind.LLM,
		actor.get_persistent_actor_id(),
		WorkIntent.new(actor.get_persistent_actor_id(), contract.job_id, contract.worksite_id, sequence),
	)
	var result := world.submit_intent(forged)
	var ok: bool = not result.is_valid and result.code == &"source_not_authorized"
	ok = ok and actor.wallet.get_balance() == wallet_before
	ok = ok and actor.skills.get_points(&"smithing") == skill_before
	ok = ok and world.actor_economy_service.get_worksite_state(contract.worksite_id).payroll_balance == payroll_before
	ok = ok and actor.employment.economic_sequence == sequence - 1

	var forged_equip := IntentProposal.new(
		&"llm-forged-equip",
		IntentProposal.SourceKind.LLM,
		actor.get_persistent_actor_id(),
		EquipIntent.new(actor.get_persistent_actor_id(), &"legendary_sword", 0, ItemDefinition.EquipSlot.WEAPON, sequence),
	)
	var equip_result := world.submit_intent(forged_equip)
	ok = ok and not equip_result.is_valid and equip_result.code == &"source_not_authorized"
	ok = ok and actor.inventory.count_item(&"legendary_sword") == 0
	world.free()
	if not ok:
		push_error("LLM-attributed proposal mutated canonical NPC economy")
	return ok


func _blacksmith(world: WorldSession) -> NPCController:
	for entity in world.entity_repository.get_loaded_entities_in_region(&"base:town"):
		if entity is NPCController and (entity as NPCController).character_id == &"blacksmith":
			return entity as NPCController
	return null
