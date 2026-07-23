extends RefCounted


func run() -> bool:
	var path := "res://scripts/dialogue/dialogue_runner.gd"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var text := file.get_as_text().to_lower()
	var forbidden := ["demo_errand", "try_deliver_herb", "start_mira_dialogue"]
	for word in forbidden:
		if text.find(word) >= 0:
			return false
	return true
