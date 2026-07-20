extends RefCounted


func run() -> bool:
	var inv := InventoryComponent.new()
	inv._ready()
	var added := inv.add_item(&"herb", 3)
	return added == 3 and inv.count_item(&"herb") == 3
