class_name CharacterController
extends CharacterBody3D
## Shared base for player, NPC, pet, and mount actors.

@export var character_id: StringName = &""
@export var definition: CharacterDefinition

@onready var health: HealthComponent = $HealthComponent
@onready var energy: EnergyComponent = $EnergyComponent
@onready var faction: FactionComponent = $FactionComponent
@onready var relationship: RelationshipComponent = $RelationshipComponent
@onready var interaction: InteractionComponent = $InteractionComponent
@onready var combat: CombatComponent = $CombatComponent
@onready var skills: SkillComponent = $SkillComponent
@onready var status: StatusEffectComponent = $StatusEffectComponent
@onready var hurtbox: Hurtbox3D = $Hurtbox3D

var state := CharacterState.new()
var game_time: float = 0.0


func _ready() -> void:
	if character_id == &"":
		character_id = StringName(str(get_instance_id()))
	if definition != null:
		apply_definition(definition)


func apply_definition(def: CharacterDefinition) -> void:
	definition = def
	character_id = def.id
	if health != null:
		health.max_health = def.max_health
		health.current_health = def.max_health
	if energy != null:
		energy.max_energy = def.max_energy
		energy.current_energy = def.max_energy
	if faction != null:
		faction.faction_id = def.faction_id


func set_input_enabled(enabled: bool) -> void:
	state.input_enabled = enabled


func to_dict() -> Dictionary:
	return {
		"character_id": String(character_id),
		"position": {
			"x": global_position.x,
			"y": global_position.y,
			"z": global_position.z,
		},
		"health": health.to_dict() if health else {},
		"energy": energy.to_dict() if energy else {},
		"relationship": relationship.to_dict() if relationship else {},
		"faction": faction.to_dict() if faction else {},
		"skills": skills.to_dict() if skills else {},
		"state": {
			"is_running": state.is_running,
			"is_crouching": state.is_crouching,
		},
	}


func from_dict(data: Dictionary) -> void:
	character_id = StringName(str(data.get("character_id", character_id)))
	var pos: Dictionary = data.get("position", {})
	global_position = Vector3(
		float(pos.get("x", global_position.x)),
		float(pos.get("y", global_position.y)),
		float(pos.get("z", global_position.z)),
	)
	if health != null:
		health.from_dict(data.get("health", {}))
	if energy != null:
		energy.from_dict(data.get("energy", {}))
	if relationship != null:
		relationship.from_dict(data.get("relationship", {}))
	if faction != null:
		faction.from_dict(data.get("faction", {}))
	if skills != null:
		skills.from_dict(data.get("skills", {}))
	var state_data: Dictionary = data.get("state", {})
	state.is_running = bool(state_data.get("is_running", false))
	state.is_crouching = bool(state_data.get("is_crouching", false))


func _on_damaged(_amount: float, _source: Node) -> void:
	pass
