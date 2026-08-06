extends RefCounted


func run() -> bool:
	var cases := {
		&"base:town": "base_town",
		&"base:wilderness": "base_wilderness",
		&"base:dungeon": "base_dungeon",
		&"chapter1:capital": "chapter1_capital",
	}
	for region_id in cases.keys():
		var filename := RegionIdUtil.to_chunk_filename(region_id)
		if filename != cases[region_id]:
			push_error("to_chunk_filename failed for %s: got %s want %s" % [region_id, filename, cases[region_id]])
			return false
		var roundtrip := RegionIdUtil.from_chunk_filename(filename + ".json")
		if roundtrip != RegionIdUtil.normalize(region_id):
			push_error("from_chunk_filename failed for %s: got %s" % [filename, roundtrip])
			return false
	return true
