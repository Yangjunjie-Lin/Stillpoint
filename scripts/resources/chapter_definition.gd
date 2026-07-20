class_name ChapterDefinition
extends Resource
## Reserved for multi-chapter story progression.

@export var id: StringName = &"chapter_01"
@export var display_name: String = "Chapter 1"
@export var levels: Array[LevelDefinition] = []
@export var unlock_after: StringName = &""
