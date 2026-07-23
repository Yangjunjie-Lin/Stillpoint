class_name RegionIdUtil
extends RefCounted
## Normalizes region IDs and provides reversible chunk filenames.

const LEGACY_MAP: Dictionary = {
	"town": "base:town",
	"wilderness": "base:wilderness",
	"dungeon": "base:dungeon",
}


static func normalize(region_id: StringName) -> StringName:
	var s := String(region_id)
	if s.is_empty():
		return &""
	if LEGACY_MAP.has(s):
		return StringName(LEGACY_MAP[s])
	if s.contains(":"):
		return region_id
	return StringName("base:%s" % s)


## Encode region id for filenames: namespace:local → namespace_local
static func to_chunk_filename(region_id: StringName) -> String:
	var norm := String(normalize(region_id))
	return norm.replace(":", "_")


## Decode chunk filename back to region id: namespace_local → namespace:local
## Uses the first underscore as the namespace separator (namespace never contains '_').
static func from_chunk_filename(filename: String) -> StringName:
	var name := filename
	if name.ends_with(".json"):
		name = name.substr(0, name.length() - 5)
	var sep := name.find("_")
	if sep < 0:
		return normalize(StringName(name))
	var ns := name.substr(0, sep)
	var rest := name.substr(sep + 1)
	return StringName("%s:%s" % [ns, rest])


static func chunk_filename(region_id: StringName) -> String:
	return to_chunk_filename(region_id)
