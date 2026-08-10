class_name LootTableDefinition
extends Resource
## Deterministic authored dungeon loot. Runtime state never lives here.

@export var id: StringName = &"loot_table"
@export_range(0.0, 1.0, 0.01) var drop_chance: float = 1.0
@export var entries: Array[LootEntryDefinition] = []


func is_valid() -> bool:
	if id == &"" or entries.is_empty():
		return false
	for entry in entries:
		if entry == null or not entry.is_valid():
			return false
	return true


func roll_one(player_level: int, seed_key: String) -> Dictionary:
	if not is_valid():
		return {}
	var eligible: Array[LootEntryDefinition] = []
	var total_weight := 0.0
	for entry in entries:
		if entry.is_eligible(player_level):
			eligible.append(entry)
			total_weight += entry.weight
	if eligible.is_empty() or total_weight <= 0.0:
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = _stable_seed(seed_key, player_level)
	if rng.randf() > drop_chance:
		return {}
	var cursor := rng.randf() * total_weight
	var selected: LootEntryDefinition = eligible.back()
	for entry in eligible:
		cursor -= entry.weight
		if cursor <= 0.0:
			selected = entry
			break
	return {
		"item_id": selected.item_id,
		"quantity": rng.randi_range(
			selected.minimum_quantity,
			selected.maximum_quantity,
		),
	}


func _stable_seed(seed_key: String, player_level: int) -> int:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(("%s|%s|%d" % [String(id), seed_key, player_level]).to_utf8_buffer())
	var digest: PackedByteArray = ctx.finish()
	var result: int = 0
	for index in mini(8, digest.size()):
		result = (result << 8) | int(digest[index])
	return maxi(1, result & 0x7FFFFFFF)
