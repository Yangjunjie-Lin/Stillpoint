class_name ItemStack
extends RefCounted

var item_id: StringName = &""
var quantity: int = 0


func is_empty() -> bool:
	return item_id == &"" or quantity <= 0
