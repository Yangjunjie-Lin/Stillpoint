class_name NPCMindDefinition
extends Resource

@export var id: StringName = &""
@export var identity: NPCIdentityDefinition
@export var personality: NPCPersonalityDefinition
@export var speech_style: NPCSpeechStyleDefinition
@export var biography: Array[String] = []
@export var values: Array[StringName] = []
@export var taboos: Array[StringName] = []
@export var goals: Array[NPCGoalDefinition] = []
@export var knowledge_seeds: Array[NPCKnowledgeSeed] = []
@export var belief_seeds: Array[NPCBeliefSeed] = []
@export var relationship_seeds: Array[NPCRelationshipSeed] = []
@export var cognitive_skills: Array[NPCCognitiveSkillDefinition] = []
@export var linked_gameplay_skill_ids: Array[StringName] = []
@export var memory_policy: NPCMemoryPolicyDefinition
@export_multiline var system_prompt_addendum: String = ""

func is_valid() -> bool:
	if id == &"" or identity == null or personality == null or speech_style == null:
		return false
	if memory_policy == null:
		return false
	var seen := {}
	for skill in cognitive_skills:
		if skill == null or skill.id == &"" or seen.has(skill.id): return false
		seen[skill.id] = true
	return true

func to_catalog_dict() -> Dictionary:
	var skill_data: Array = []
	for skill in cognitive_skills:
		if skill != null: skill_data.append(skill.to_catalog_dict())
	var knowledge_data: Array = []
	for seed in knowledge_seeds:
		if seed != null: knowledge_data.append(seed.to_catalog_dict())
	var belief_data: Array = []
	for seed in belief_seeds:
		if seed != null: belief_data.append(seed.to_catalog_dict())
	var goal_data: Array = []
	for goal in goals:
		if goal != null: goal_data.append(goal.to_catalog_dict())
	var relationship_data: Array = []
	for relation in relationship_seeds:
		if relation != null: relationship_data.append(relation.to_catalog_dict())
	return {"id": String(id), "identity": identity.to_catalog_dict(),
		"personality": personality.to_catalog_dict(),
		"speech_style": speech_style.to_catalog_dict(), "biography": biography.duplicate(),
		"values": _strings(values), "taboos": _strings(taboos), "goals": goal_data,
		"knowledge_seeds": knowledge_data, "belief_seeds": belief_data,
		"relationship_seeds": relationship_data, "cognitive_skills": skill_data,
		"linked_gameplay_skill_ids": _strings(linked_gameplay_skill_ids),
		"memory_policy": memory_policy.to_catalog_dict(),
		"system_prompt_addendum": system_prompt_addendum}

func _strings(items: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for item in items: result.append(String(item))
	return result
