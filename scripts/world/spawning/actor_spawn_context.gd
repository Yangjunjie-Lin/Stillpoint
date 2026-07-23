class_name ActorSpawnContext
extends RefCounted

var definition_id: StringName = &""
var persistent_id: StringName = &""
var region_id: StringName = &""
var spawn_id: StringName = &""
var transform: Transform3D = Transform3D.IDENTITY
var parent: Node = null
var snapshot: EntitySnapshot = null
