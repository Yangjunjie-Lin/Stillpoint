class_name CharacterDefinition
extends Resource

@export var id: StringName = &"character"
@export var display_name: String = "Character"
@export var character_scene: PackedScene
@export var portrait: Texture2D
@export var faction_id: StringName = &"neutral"
@export var default_disposition: StringName = &"neutral"
@export var max_health: float = 100.0
@export var max_energy: float = 100.0
@export var walk_speed: float = 4.0
@export var run_speed: float = 7.0
@export var crouch_speed: float = 2.5
@export var jump_velocity: float = 6.5
@export var skills: Array[SkillDefinition] = []
@export var default_dialogue: DialogueDefinition
@export var schedule: ScheduleDefinition
@export var can_be_attacked: bool = true
@export var can_be_killed: bool = false
