class_name PlayerOntologySnapshotBuilder
extends RefCounted
## Builds the bounded, public player context that an NPC may observe.
##
## This snapshot deliberately excludes private/runtime state such as the
## attribute seed, exact stat values, inventory, equipment and player history.

const SCHEMA_VERSION: int = 1
const MAX_DISPLAY_NAME_LENGTH: int = 24
const MAX_ID_LENGTH: int = 64
const MAX_LABEL_LENGTH: int = 64
const MAX_CAPABILITIES: int = 6

const APPEARANCE_FIELDS: Dictionary = {
	"body_id": "body_id",
	"skin_id": "skin_id",
	"hair_id": "hair_id",
	"headwear_id": "headwear_id",
	"palette_id": "palette_id",
	"accessory_id": "accessory_id",
}

const CAPABILITY_TRAIT_IDS: Dictionary = {
	&"max_health_bonus": "resilient",
	&"max_energy_bonus": "energetic",
	&"attack_bonus": "forceful",
	&"defense_bonus": "guarded",
	&"move_speed_bonus": "agile",
	&"energy_regen_bonus": "focused",
}


static func build(player: PlayerController3D, display_name: String) -> Dictionary:
	if player == null or not is_instance_valid(player):
		return {}
	var origin := ResourceRegistry.get_origin(player.origin_id)
	var faction := ResourceRegistry.get_faction(player.selected_faction_id)
	var profession := ResourceRegistry.get_profession(player.profession_id)
	if origin == null or faction == null or profession == null:
		return {}

	var normalized_appearance := CharacterAppearanceOptions.normalize(
		player.appearance_options
	)
	var visible_appearance: Dictionary = {}
	for public_key: String in APPEARANCE_FIELDS:
		var internal_key: String = APPEARANCE_FIELDS[public_key]
		visible_appearance[public_key] = _bounded_id(
			str(normalized_appearance.get(internal_key, ""))
		)

	return {
		"schema_version": SCHEMA_VERSION,
		"public_identity": {
			"display_name": _bounded_text(
				display_name, MAX_DISPLAY_NAME_LENGTH, "Traveler"
			),
			"origin_id": _bounded_id(String(origin.id)),
			"origin_label": _bounded_text(origin.display_name, MAX_LABEL_LENGTH),
			"faction_id": _bounded_id(String(faction.id)),
			"faction_label": _bounded_text(faction.display_name, MAX_LABEL_LENGTH),
			"profession_id": _bounded_id(String(profession.id)),
			"profession_label": _bounded_text(profession.display_name, MAX_LABEL_LENGTH),
		},
		"visible_appearance": visible_appearance,
		"observable_capabilities": _build_capabilities(player, faction, profession),
	}


static func _build_capabilities(
	player: PlayerController3D,
	faction: FactionDefinition,
	profession: ProfessionDefinition,
) -> Array[Dictionary]:
	var evidence_by_stat: Dictionary = {}
	var faction_stat := CharacterBuildCalculator.signature_bonus_key(faction)
	if faction_stat != &"":
		evidence_by_stat[faction_stat] = "faction"
	var profession_stat := CharacterBuildCalculator.signature_bonus_key(profession)
	if profession_stat != &"":
		# A profession is the more immediate observable explanation when both
		# public build choices share one signature tendency.
		evidence_by_stat[profession_stat] = "profession"

	# Only a pronounced randomized aptitude is exposed, and only as a word.
	# The seed, point allocation and relative numeric magnitude remain private.
	var random_points := CharacterBuildCalculator.roll_attribute_points(
		player.attribute_seed
	)
	for stat_key in CharacterBuildCalculator.STAT_BONUS_KEYS:
		if (
			not evidence_by_stat.has(stat_key)
			and int(random_points.get(stat_key, 0))
			>= CharacterBuildCalculator.RANDOM_MAX_PER_STAT
		):
			evidence_by_stat[stat_key] = "observable_build"

	var result: Array[Dictionary] = []
	for stat_key in CharacterBuildCalculator.STAT_BONUS_KEYS:
		if result.size() >= MAX_CAPABILITIES or not evidence_by_stat.has(stat_key):
			continue
		var trait_id := str(CAPABILITY_TRAIT_IDS.get(stat_key, ""))
		if trait_id.is_empty():
			continue
		result.append({
			"trait_id": _bounded_id(trait_id),
			"evidence": str(evidence_by_stat[stat_key]),
			"visibility": "public",
		})
	return result


static func _bounded_id(value: String) -> String:
	return _bounded_text(value, MAX_ID_LENGTH)


static func _bounded_text(value: String, limit: int, fallback: String = "") -> String:
	var normalized := value.replace("\r", " ").replace("\n", " ").replace("\t", " ")
	while normalized.contains("  "):
		normalized = normalized.replace("  ", " ")
	normalized = normalized.strip_edges().left(limit)
	return fallback if normalized.is_empty() else normalized
