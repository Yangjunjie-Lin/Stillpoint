extends RefCounted


func run() -> bool:
	var ok := _missing_relationship_is_not_registered()
	ok = _expired_hostility_is_observed_without_cleanup() and ok
	ok = _story_hostility_is_read_without_mutation() and ok
	RelationshipService.reset_all()
	if not ok:
		push_error("Relationship/Disposition conditions mutated relationship state")
	return ok


func _missing_relationship_is_not_registered() -> bool:
	RelationshipService.reset_all()
	var relationship := RelationshipCondition.new()
	relationship.npc_id = &"unregistered_npc"
	relationship.min_affinity = -1.0
	relationship.max_affinity = 1.0
	var disposition := DispositionCondition.new()
	disposition.npc_id = &"unregistered_npc"
	disposition.required_disposition = RelationshipComponent.Disposition.NEUTRAL
	var before := RelationshipService.to_dict()
	var matched := relationship.evaluate(null) and disposition.evaluate(null)
	return matched and RelationshipService.to_dict() == before


func _expired_hostility_is_observed_without_cleanup() -> bool:
	RelationshipService.reset_all()
	RelationshipService.from_dict({
		"states": {
			&"expired_npc": {
				"affinity": 60.0,
				"temporary_hostile": true,
				"anger": 10.0,
				"last_aggression_time": (
					Time.get_unix_time_from_system()
					- RelationshipService.TEMPORARY_HOSTILE_DURATION_SECONDS
					- 1.0
				),
			},
		},
	})
	var relationship := RelationshipCondition.new()
	relationship.npc_id = &"expired_npc"
	relationship.min_affinity = 50.0
	var disposition := DispositionCondition.new()
	disposition.npc_id = &"expired_npc"
	disposition.required_disposition = RelationshipComponent.Disposition.FRIENDLY
	var before := RelationshipService.to_dict()
	var matched := relationship.evaluate(null) and disposition.evaluate(null)
	var unchanged := RelationshipService.to_dict() == before
	# The ordinary gameplay getter remains backward-compatible: it observes the
	# same disposition and performs the historical lazy cleanup.
	var regular := RelationshipService.get_disposition(&"expired_npc")
	var state: Dictionary = RelationshipService.to_dict().get("states", {}).get(&"expired_npc", {})
	return (
		matched
		and unchanged
		and regular == RelationshipComponent.Disposition.FRIENDLY
		and not bool(state.get("temporary_hostile", true))
	)


func _story_hostility_is_read_without_mutation() -> bool:
	RelationshipService.reset_all()
	RelationshipService.from_dict({
		"states": {
			&"story_npc": {
				"affinity": 60.0,
				"temporary_hostile": true,
				"anger": 10.0,
				"last_aggression_time": (
					Time.get_unix_time_from_system()
					- RelationshipService.TEMPORARY_HOSTILE_DURATION_SECONDS
					- 1.0
				),
			},
		},
	})
	# A story effect takes ownership from an expired aggression TTL and remains
	# authoritative until explicitly cleared.
	RelationshipService.set_temporary_hostile(&"story_npc", true)
	var disposition := DispositionCondition.new()
	disposition.npc_id = &"story_npc"
	disposition.required_disposition = RelationshipComponent.Disposition.HOSTILE
	var before := RelationshipService.to_dict()
	return (
		disposition.evaluate(null)
		and RelationshipService.to_dict() == before
		and RelationshipService.get_disposition(&"story_npc")
		== RelationshipComponent.Disposition.HOSTILE
	)
