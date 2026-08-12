class_name PetSkillDefinition
extends Resource
## Pet-specific life or attack skill. `program_action_id` names an audited
## gameplay action; generated text never supplies damage or state deltas.

enum SkillKind {
	LIFE,
	ATTACK,
}

@export var id: StringName = &"pet_skill"
@export var display_name: String = "Pet Skill"
@export_multiline var description: String = ""
@export var kind: SkillKind = SkillKind.LIFE
@export var program_action_id: StringName = &""
@export var governing_attribute: StringName = &"focus"
@export_range(0.0, 1000.0, 0.1) var stamina_cost: float = 0.0
@export_range(0.0, 3600.0, 0.05) var cooldown_seconds: float = 0.0
@export_range(0.0, 10000.0, 0.1) var base_power: float = 0.0
@export_range(0.0, 1000.0, 0.1) var range: float = 1.5
@export_range(0.01, 100.0, 0.01) var proficiency_gain_per_use: float = 1.0
@export_range(1.0, 1000.0, 1.0) var max_proficiency: float = 100.0
@export_range(1, 100, 1) var required_level: int = 1
@export var tags: Array[StringName] = []


func is_valid() -> bool:
	return (
		id != &""
		and not display_name.strip_edges().is_empty()
		and program_action_id != &""
		and stamina_cost >= 0.0
		and cooldown_seconds >= 0.0
		and proficiency_gain_per_use > 0.0
		and max_proficiency > 0.0
		and required_level > 0
	)


func is_attack_skill() -> bool:
	return kind == SkillKind.ATTACK


func ontology_node_id() -> StringName:
	var raw := String(id)
	return id if raw.begins_with("pet_skill:") \
		else StringName("pet_skill:%s" % raw)


func to_catalog_dict() -> Dictionary:
	var string_tags: Array[String] = []
	for tag in tags:
		string_tags.append(String(tag))
	return {
		"node_id": String(ontology_node_id()),
		"node_type": "pet_skill",
		"label": display_name,
		"metadata": {
			"definition_id": String(id),
			"description": description,
			"kind": "attack" if is_attack_skill() else "life",
			"program_action_id": String(program_action_id),
			"governing_attribute": String(governing_attribute),
			"required_level": required_level,
			"tags": string_tags,
		},
	}
