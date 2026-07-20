class_name ItemSelection
extends RefCounted
## Weighted ItemDefinition picks for spawn pools.


static func choose_weighted_item(
	definitions: Array,
	player_level: int,
	rng: RandomNumberGenerator,
) -> ItemDefinition:
	var eligible: Array[ItemDefinition] = []
	var weights: Array[float] = []
	var total := 0.0
	for entry in definitions:
		var def := entry as ItemDefinition
		if def == null:
			continue
		if def.spawn_weight <= 0.0:
			continue
		if player_level < def.minimum_level:
			continue
		eligible.append(def)
		weights.append(def.spawn_weight)
		total += def.spawn_weight
	if eligible.is_empty() or total <= 0.0:
		return null
	var roll := rng.randf() * total
	var cursor := 0.0
	for i in eligible.size():
		cursor += weights[i]
		if roll <= cursor:
			return eligible[i]
	return eligible[eligible.size() - 1]
