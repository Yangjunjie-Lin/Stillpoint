class_name RegionIdUtil
extends RefCounted
## Normalizes legacy and namespaced region IDs.

const LEGACY_MAP: Dictionary = {
	"town": "base:town",
	"wilderness": "base:wilderness",
	"dungeon": "base:dungeon",
}


static func normalize(region_id: StringName) -> StringName:
	var s := String(region_id)
	if LEGACY_MAP.has(s):
		return StringName(LEGACY_MAP[s])
	if s.begins_with("base:"):
		return region_id
	return StringName("base:%s" % s)


static func chunk_filename(region_id: StringName) -> String:
	return String(normalize(region_id)).replace(":", "_")
