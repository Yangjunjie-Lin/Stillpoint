class_name PersistentIdGenerator
extends RefCounted
## Generates stable runtime persistent IDs within a region/category namespace.

static func next_instance_id(region_id: StringName, category: StringName, counter: int) -> StringName:
	var region := RegionIdUtil.normalize(region_id)
	return StringName("base:%s/%s/%04d" % [String(region).trim_prefix("base:"), category, counter])
