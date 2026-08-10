class_name CharacterBuildCalculator
extends RefCounted
## Pure, deterministic helpers for balanced player character builds.

const STAT_BONUS_KEYS: Array[StringName] = [
	&"max_health_bonus",
	&"max_energy_bonus",
	&"attack_bonus",
	&"defense_bonus",
	&"move_speed_bonus",
	&"energy_regen_bonus",
]

const BONUS_TO_STAT: Dictionary = {
	&"max_health_bonus": &"max_health",
	&"max_energy_bonus": &"max_energy",
	&"attack_bonus": &"attack",
	&"defense_bonus": &"defense",
	&"move_speed_bonus": &"move_speed",
	&"energy_regen_bonus": &"energy_regen",
}

# One normalized point always costs the same build budget. The conversion keeps
# unlike gameplay units (health, speed, regeneration) comparable.
const VALUE_PER_POINT: Dictionary = {
	&"max_health_bonus": 4.0,
	&"max_energy_bonus": 4.0,
	&"attack_bonus": 0.5,
	&"defense_bonus": 0.5,
	&"move_speed_bonus": 0.05,
	&"energy_regen_bonus": 0.1,
}

const BUILD_SECTION_VERSION: int = 2
const ATTRIBUTE_GENERATION_VERSION: int = 1
const RANDOM_POINT_BUDGET: int = 6
const RANDOM_MIN_PER_STAT: int = 0
const RANDOM_MAX_PER_STAT: int = 2
const FACTION_SIGNATURE_POINTS: int = 2
const PROFESSION_SIGNATURE_POINTS: int = 4
const TOTAL_BUILD_POINT_BUDGET: int = (
	RANDOM_POINT_BUDGET + FACTION_SIGNATURE_POINTS + PROFESSION_SIGNATURE_POINTS
)
const MAX_SEED: int = 2_147_483_647
const BASE_PHYSICAL_STRENGTH: int = 5


static func calculate_bonuses(
	_origin: CharacterOriginDefinition,
	faction: FactionDefinition,
	profession: ProfessionDefinition,
	attribute_points: Dictionary = {},
) -> Dictionary:
	var totals := attribute_points_to_bonuses(attribute_points)
	_add_signature(totals, faction)
	_add_signature(totals, profession)
	return totals


static func calculate_stats(
	base_stats: Dictionary,
	origin: CharacterOriginDefinition,
	faction: FactionDefinition,
	profession: ProfessionDefinition,
	attribute_points: Dictionary = {},
) -> Dictionary:
	return apply_bonuses(
		base_stats,
		calculate_bonuses(origin, faction, profession, attribute_points),
	)


static func apply_bonuses(base_stats: Dictionary, bonuses: Dictionary) -> Dictionary:
	var result := base_stats.duplicate(true)
	for bonus_key in STAT_BONUS_KEYS:
		var stat_key: StringName = BONUS_TO_STAT[bonus_key]
		var base_value := float(result.get(stat_key, result.get(String(stat_key), 0.0)))
		var bonus_value := float(bonuses.get(bonus_key, bonuses.get(String(bonus_key), 0.0)))
		result[stat_key] = base_value + bonus_value
	return result


static func physical_strength_from_bonuses(bonuses: Dictionary) -> int:
	## Strength is an innate build capability, not equipped weapon damage.
	var attack_bonus := float(bonuses.get(
		&"attack_bonus", bonuses.get("attack_bonus", 0.0)
	))
	var point_value := float(VALUE_PER_POINT[&"attack_bonus"])
	var physical_points := maxi(0, roundi(attack_bonus / point_value))
	return BASE_PHYSICAL_STRENGTH + physical_points


static func empty_bonuses() -> Dictionary:
	var result: Dictionary = {}
	for key in STAT_BONUS_KEYS:
		result[key] = 0.0
	return result


static func create_seed(salt: String = "") -> int:
	var mixed := int(Time.get_unix_time_from_system())
	mixed ^= Time.get_ticks_usec()
	mixed ^= hash(salt)
	return normalize_seed(mixed)


static func normalize_seed(value: Variant, fallback: int = 804_020) -> int:
	var seed := fallback
	if typeof(value) == TYPE_INT:
		seed = int(value)
	elif (
		typeof(value) == TYPE_FLOAT
		and is_finite(float(value))
		and is_equal_approx(float(value), float(int(value)))
	):
		seed = int(value)
	seed %= MAX_SEED
	if seed <= 0:
		seed += MAX_SEED - 1
	return seed


static func roll_attribute_points(seed: int) -> Dictionary:
	var result: Dictionary = {}
	for key in STAT_BONUS_KEYS:
		result[key] = RANDOM_MIN_PER_STAT
	var remaining := RANDOM_POINT_BUDGET - RANDOM_MIN_PER_STAT * STAT_BONUS_KEYS.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = normalize_seed(seed)
	while remaining > 0:
		var eligible: Array[StringName] = []
		for key in STAT_BONUS_KEYS:
			if int(result[key]) < RANDOM_MAX_PER_STAT:
				eligible.append(key)
		if eligible.is_empty():
			break
		var picked := eligible[rng.randi_range(0, eligible.size() - 1)]
		result[picked] = int(result[picked]) + 1
		remaining -= 1
	return result


static func normalize_attribute_points(value: Variant, seed: int) -> Dictionary:
	var expected := roll_attribute_points(seed)
	if value is Dictionary and is_valid_attribute_points(value as Dictionary):
		var canonical: Dictionary = {}
		for key in STAT_BONUS_KEYS:
			canonical[key] = int((value as Dictionary).get(key, (value as Dictionary).get(String(key), 0)))
		if canonical == expected:
			return canonical
	return expected


static func is_valid_attribute_points(points: Dictionary) -> bool:
	var total := 0
	for key in STAT_BONUS_KEYS:
		var value: Variant = points.get(key, points.get(String(key), null))
		if typeof(value) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(value)):
			return false
		var amount := int(value)
		if not is_equal_approx(float(value), float(amount)):
			return false
		if amount < RANDOM_MIN_PER_STAT or amount > RANDOM_MAX_PER_STAT:
			return false
		total += amount
	return total == RANDOM_POINT_BUDGET


static func attribute_points_to_bonuses(points: Dictionary) -> Dictionary:
	var bonuses := empty_bonuses()
	if points.is_empty():
		return bonuses
	for key in STAT_BONUS_KEYS:
		var amount := int(points.get(key, points.get(String(key), 0)))
		bonuses[key] = amount * float(VALUE_PER_POINT[key])
	return bonuses


static func signature_bonus_key(source: Resource) -> StringName:
	if not (source is FactionDefinition) and not (source is ProfessionDefinition):
		return &""
	var key := StringName(str(source.get("signature_stat")))
	return key if STAT_BONUS_KEYS.has(key) else &""


static func signature_point_count(source: Resource) -> int:
	if source is FactionDefinition:
		return FACTION_SIGNATURE_POINTS
	if source is ProfessionDefinition:
		return PROFESSION_SIGNATURE_POINTS
	return 0


static func _add_signature(totals: Dictionary, source: Resource) -> void:
	var key := signature_bonus_key(source)
	if key == &"":
		return
	totals[key] = float(totals[key]) + signature_point_count(source) * float(VALUE_PER_POINT[key])
