extends RefCounted


func run() -> bool:
	var coordinator := WorldSaveCoordinator.new()
	var chunk := {
		"region_id": "base:town",
		"region_state_version": 1,
		"entities": {
			"bad_entry": "not_a_dict",
			"base:town/interactable/chest_0001": {
				"persistent_id": "base:town/interactable/chest_0001",
				"definition_id": "chest",
				"region_id": "base:town",
				"components": {"chest": {"opened": true}},
			},
		},
		"destroyed_entities": [],
		"spawn_states": {},
		"custom_state": {},
	}
	coordinator._write_json("user://saves/slot_01/regions/base_town.json", chunk)
	coordinator._write_manifest_data(&"base:town", &"spawn")
	coordinator._write_json("user://saves/slot_01/player.json", {
		"player": {"position": {"x": 0, "y": 1.2, "z": 0}},
		"inventory": {},
	})

	var loaded := coordinator._read_region_chunk_file("base_town.json", &"base:town")
	var entities: Dictionary = loaded.get("entities", {})
	if entities.has("bad_entry"):
		push_error("corrupt entity snapshot was not skipped")
		coordinator.clear_save()
		coordinator.free()
		return false
	if not bool(entities.get("base:town/interactable/chest_0001", {}).get("persistent_id", "").contains("chest")):
		push_error("valid entity snapshot was skipped")
		coordinator.clear_save()
		coordinator.free()
		return false

	coordinator.clear_save()
	coordinator.free()
	return true
