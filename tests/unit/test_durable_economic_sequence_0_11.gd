extends RefCounted


func run() -> bool:
	var actor := EconomicTestHelper.make_blacksmith_actor(&"npc:sequence")
	var ok: bool = actor.employment.commit_sequence(1)
	ok = ok and not actor.employment.commit_sequence(1)
	ok = ok and not actor.employment.commit_sequence(3)
	var saved := actor.employment.to_dict()
	var restored := EmploymentComponent.new()
	ok = restored.from_dict(saved) and ok
	ok = ok and restored.economic_sequence == 1
	ok = ok and not restored.can_commit_sequence(1)
	ok = ok and restored.can_commit_sequence(2) and restored.commit_sequence(2)
	ok = ok and restored.economic_sequence == 2
	actor.free()
	restored.free()
	if not ok:
		push_error("bounded durable economic replay high-water sequence failed")
	return ok
