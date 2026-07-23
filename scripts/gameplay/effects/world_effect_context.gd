class_name WorldEffectContext
extends RefCounted

var session_context: WorldSessionContext
var source_entity_id: StringName = &""
var target_entity_id: StringName = &""


func _init(ctx: WorldSessionContext = null) -> void:
	session_context = ctx
