extends RefCounted


func run() -> bool:
	var bar := HotbarController.new()
	var start := bar.selected_index
	bar.select_next()
	bar.select_previous()
	return bar.selected_index == start
