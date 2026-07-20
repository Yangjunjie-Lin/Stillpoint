class_name RegionDefinition
extends Resource

@export var id: StringName = &"region"
@export var display_name: String = "Region"
@export var scene: PackedScene
@export var region_type: StringName = &"outdoor"
@export var allowed_mount_tags: Array[StringName] = []
@export var default_spawn_id: StringName = &"spawn"
@export var music: AudioStream
@export var weather_profile: Resource
@export var encounter_table: Resource
