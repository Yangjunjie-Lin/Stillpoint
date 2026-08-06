extends RefCounted


func run() -> bool:
	var quest := QuestDefinition.new()
	quest.id = &"integration_new_adventure_reset"
	var objective := ObjectiveDefinition.new()
	objective.id = &"wait"
	objective.objective_type = ObjectiveDefinition.ObjectiveType.CUSTOM
	quest.objectives = [objective]
	ResourceRegistry.register_quest(quest)
	QuestManager.start_quest(quest.id)
	RelationshipService.ensure_registered(&"new_adventure_reset_npc", &"friendly")
	RelationshipService.change_affinity(&"new_adventure_reset_npc", -17.0)
	WorldTimeService.set_time(4, 19, 37)
	WorldTimeService.paused = true
	WorldTimeService.time_scale = 3.0

	var tree := Engine.get_main_loop() as SceneTree
	var main := (load("res://scenes/bootstrap/main.tscn") as PackedScene).instantiate()
	tree.root.add_child(main)
	GameManager.start_new_adventure("Reset Tester")

	# World boot may re-register authored NPCs with default disposition; the prior
	# session's quest / affinity mutation / clock must not survive the reset.
	var relationship_data := RelationshipService.to_dict()
	var states := relationship_data.get("states", {}) as Dictionary
	var prior_npc_state: Variant = states.get(&"new_adventure_reset_npc", states.get("new_adventure_reset_npc", null))
	var ok := QuestManager.get_runtime(quest.id) == null
	ok = ok and prior_npc_state == null
	ok = ok and WorldTimeService.day == 1
	ok = ok and WorldTimeService.hour == 8
	ok = ok and WorldTimeService.minute == 0
	ok = ok and not WorldTimeService.paused
	ok = ok and is_equal_approx(WorldTimeService.time_scale, 1.0)
	if not ok:
		push_error("New Adventure retained quest, relationship, or world-time memory")
	main.free()
	return ok
