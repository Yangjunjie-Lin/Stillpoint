extends RefCounted


func run() -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var ok := true

	ok = ok and ItemSelection.choose_weighted_item([], 1, rng) == null

	var low := ItemDefinition.new()
	low.id = &"locked"
	low.spawn_weight = 1.0
	low.minimum_level = 5

	var open := ItemDefinition.new()
	open.id = &"open"
	open.spawn_weight = 1.0
	open.minimum_level = 1

	var negative := ItemDefinition.new()
	negative.id = &"neg"
	negative.spawn_weight = -2.0
	negative.minimum_level = 1

	var picked := ItemSelection.choose_weighted_item([low, open, negative], 1, rng)
	ok = ok and picked == open

	picked = ItemSelection.choose_weighted_item([low], 1, rng)
	ok = ok and picked == null

	var heavy := ItemDefinition.new()
	heavy.id = &"heavy"
	heavy.spawn_weight = 1000.0
	heavy.minimum_level = 1
	var counts := {"open": 0, "heavy": 0}
	for _i in 200:
		var choice := ItemSelection.choose_weighted_item([open, heavy], 10, rng)
		counts[String(choice.id)] = int(counts[String(choice.id)]) + 1
	ok = ok and int(counts["heavy"]) > int(counts["open"])

	if not ok:
		push_error("ItemSelection assertions failed")
	return ok
