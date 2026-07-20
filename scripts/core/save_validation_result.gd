class_name SaveValidationResult
extends RefCounted

var valid: bool = false
var reason: StringName = &"unknown"
var errors: PackedStringArray = PackedStringArray()
var normalized_payload: Dictionary = {}
