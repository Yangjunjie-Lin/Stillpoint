class_name PetMotionProfile
extends RefCounted
## Deterministic movement temperament for one pet instance.
##
## Authored species/personality remain the source of truth. A small stable
## per-instance offset prevents two pets of the same definition from behaving
## like clones without using global randomness or mutating authored resources.

const TRAIT_IDS: Array[StringName] = [
	&"courage",
	&"curiosity",
	&"sociability",
	&"independence",
	&"loyalty",
	&"playfulness",
	&"aggression",
	&"patience",
]
const MOTIF_IDS: Array[StringName] = [
	&"idle_near_anchor",
	&"follow_owner",
	&"curious_explore",
	&"playful_loop",
	&"social_approach",
	&"cautious_patrol",
	&"perch_observe",
	&"rest_sheltered",
]
const INDIVIDUAL_OFFSET_LIMIT := 0.1
const HASH_MASK := 0x7fffffff
const HASH_DENOMINATOR := 2147483647.0

var persistent_id: StringName = &"pet"
var species_id: StringName = &"pet_species"
var visual_archetype: StringName = &"quadruped"
var species_tags: Array[StringName] = []
var habitat_tags: Array[StringName] = []
var authored_traits: Dictionary = {}
var individual_offsets: Dictionary = {}
var individual_traits: Dictionary = {}


func setup(definition: Variant, pet_persistent_id: StringName) -> void:
	persistent_id = pet_persistent_id if pet_persistent_id != &"" else &"pet"
	species_tags.clear()
	habitat_tags.clear()
	authored_traits.clear()
	individual_offsets.clear()
	individual_traits.clear()

	var species: Variant = _value_from(definition, &"species", null)
	species_id = StringName(str(_value_from(species, &"id", &"pet_species")))
	visual_archetype = StringName(str(_value_from(
		species, &"visual_archetype", &"quadruped"
	)).to_lower())
	species_tags = _safe_tags(_value_from(species, &"species_tags", []))
	habitat_tags = _safe_tags(_value_from(species, &"habitat_tags", []))
	var personality: Variant = _value_from(definition, &"personality", null)
	for trait_id in TRAIT_IDS:
		var authored := clampf(float(_value_from(personality, trait_id, 0.5)), 0.0, 1.0)
		var offset := (_stable_unit("trait:%s" % String(trait_id)) * 2.0 - 1.0) \
			* INDIVIDUAL_OFFSET_LIMIT
		authored_traits[String(trait_id)] = authored
		individual_offsets[String(trait_id)] = offset
		individual_traits[String(trait_id)] = clampf(authored + offset, 0.0, 1.0)


func get_individual_traits() -> Dictionary:
	return individual_traits.duplicate(true)


func get_individual_offsets() -> Dictionary:
	return individual_offsets.duplicate(true)


func energy() -> float:
	return clampf(
		_trait(&"curiosity") * 0.32
		+ _trait(&"playfulness") * 0.38
		+ _trait(&"independence") * 0.18
		+ (1.0 - _trait(&"patience")) * 0.12,
		0.0,
		1.0,
	)


func base_motif_weights() -> Dictionary:
	var weights := {
		"idle_near_anchor": 0.18 + _trait(&"patience") * 0.42,
		"follow_owner": 0.15 + _trait(&"loyalty") * 0.5
			+ _trait(&"sociability") * 0.18,
		"curious_explore": 0.12 + _trait(&"curiosity") * 0.52
			+ _trait(&"independence") * 0.18,
		"playful_loop": 0.08 + _trait(&"playfulness") * 0.58,
		"social_approach": 0.1 + _trait(&"sociability") * 0.5
			+ _trait(&"loyalty") * 0.12,
		"cautious_patrol": 0.12 + _trait(&"patience") * 0.28
			+ _trait(&"courage") * 0.18 + _trait(&"aggression") * 0.12,
		"perch_observe": 0.1 + _trait(&"patience") * 0.32
			+ _trait(&"curiosity") * 0.18,
		"rest_sheltered": 0.16 + _trait(&"patience") * 0.32
			+ (1.0 - _trait(&"aggression")) * 0.18,
	}
	_apply_species_biases(weights)
	for motif_id in MOTIF_IDS:
		var key := String(motif_id)
		weights[key] = clampf(float(weights.get(key, 0.1)), 0.02, 1.0)
	return weights


func motif_weights_for(
	mood_band: StringName,
	region_type: StringName,
	region_tags: Array[StringName],
) -> Dictionary:
	var weights := base_motif_weights()
	_apply_mood_biases(weights, mood_band)
	_apply_region_biases(weights, region_type, region_tags)
	for motif_id in MOTIF_IDS:
		var key := String(motif_id)
		weights[key] = clampf(float(weights.get(key, 0.1)), 0.02, 1.0)
	return weights


func habitat_affinity(candidate_tags: Array[StringName], region_tags: Array[StringName]) -> float:
	var matches := 0
	for tag in candidate_tags:
		if habitat_tags.has(tag) or region_tags.has(tag):
			matches += 1
	return clampf(float(matches) * 0.12, 0.0, 0.36)


func _apply_species_biases(weights: Dictionary) -> void:
	if _has_any(species_tags, [&"fox"]):
		weights["curious_explore"] += 0.18
		weights["playful_loop"] += 0.12
	if _has_any(species_tags, [&"hound", &"stonehide", &"guardian"]):
		weights["follow_owner"] += 0.12
		weights["cautious_patrol"] += 0.2
	if visual_archetype == &"cloudowl" or _has_any(
		species_tags, [&"avian", &"flying", &"owl"]
	):
		weights["perch_observe"] += 0.3
		weights["curious_explore"] += 0.1
		weights["playful_loop"] -= 0.05
	if _has_any(species_tags, [&"small_companion"]):
		weights["playful_loop"] += 0.05
	if _has_any(species_tags, [&"medium_companion"]):
		weights["cautious_patrol"] += 0.06


func _apply_mood_biases(weights: Dictionary, mood_band: StringName) -> void:
	match mood_band:
		&"happy":
			weights["playful_loop"] += 0.24
			weights["social_approach"] += 0.14
			weights["curious_explore"] += 0.1
			weights["rest_sheltered"] -= 0.1
		&"anxious":
			weights["cautious_patrol"] += 0.2
			weights["rest_sheltered"] += 0.18
			weights["follow_owner"] += 0.1
			weights["curious_explore"] -= 0.12
		&"sad":
			weights["rest_sheltered"] += 0.28
			weights["idle_near_anchor"] += 0.2
			weights["playful_loop"] -= 0.18
			weights["curious_explore"] -= 0.14
		_:
			pass


func _apply_region_biases(
	weights: Dictionary,
	region_type: StringName,
	region_tags: Array[StringName],
) -> void:
	var semantics := region_tags.duplicate()
	if region_type != &"" and not semantics.has(region_type):
		semantics.append(region_type)
	if _has_any(semantics, [&"home", &"indoors", &"interior"]):
		weights["rest_sheltered"] += 0.18
		weights["idle_near_anchor"] += 0.14
	if _has_any(semantics, [&"town", &"village", &"social"]):
		weights["social_approach"] += 0.15
		weights["idle_near_anchor"] += 0.08
	if _has_any(semantics, [&"wilderness", &"farmland", &"outdoor"]):
		weights["curious_explore"] += 0.14
		weights["playful_loop"] += 0.06
	if _has_any(semantics, [&"dungeon", &"dangerous", &"hostile"]):
		weights["cautious_patrol"] += 0.24
		weights["follow_owner"] += 0.12
		weights["playful_loop"] -= 0.12
	if _has_any(semantics, [&"highland", &"perch", &"vertical"]):
		weights["perch_observe"] += 0.18


func _trait(trait_id: StringName) -> float:
	return clampf(float(individual_traits.get(String(trait_id), 0.5)), 0.0, 1.0)


func _stable_unit(salt: String) -> float:
	var hashed := int(("%s|%s" % [String(persistent_id), salt]).hash()) & HASH_MASK
	return float(hashed) / HASH_DENOMINATOR


func _value_from(source: Variant, key: StringName, default_value: Variant) -> Variant:
	if source is Dictionary:
		if source.has(key):
			return source[key]
		if source.has(String(key)):
			return source[String(key)]
	elif source is Object and is_instance_valid(source):
		var object := source as Object
		for property in object.get_property_list():
			if StringName(str(property.get("name", ""))) == key:
				return object.get(key)
	return default_value


func _safe_tags(value: Variant) -> Array[StringName]:
	var result: Array[StringName] = []
	if not value is Array:
		return result
	for raw in value as Array:
		var tag := StringName(str(raw).strip_edges().to_lower())
		if tag != &"" and not result.has(tag):
			result.append(tag)
	return result


func _has_any(haystack: Array[StringName], needles: Array) -> bool:
	for needle in needles:
		if haystack.has(StringName(str(needle))):
			return true
	return false
