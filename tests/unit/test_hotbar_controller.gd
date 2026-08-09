extends RefCounted


func run() -> bool:
	var bar := HotbarController.new()
	var start := bar.selected_index
	bar.select_next()
	bar.select_previous()
	var ok := bar.selected_index == start
	ok = ok and bar.select_index(7) and bar.selected_index == 7
	ok = ok and not bar.select_index(8) and bar.selected_index == 7
	return ok
