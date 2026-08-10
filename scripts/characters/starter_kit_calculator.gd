class_name StarterKitCalculator
extends RefCounted
## Grants profession-flavoured starter items under one shared value budget.

const TARGET_VALUE: int = 25
const DEFAULT_ITEMS: Dictionary = {
	"field_pick": 1,
	"padded_vest": 1,
	"trail_snack": 3,
	"training_sword": 1,
	"wanderer_charm": 1,
}
const DEFAULT_ITEM_ORDER: Array[StringName] = [
	&"training_sword",
	&"field_pick",
	&"trail_snack",
	&"padded_vest",
	&"wanderer_charm",
]


static func calculate_value(profession: ProfessionDefinition) -> int:
	if profession == null or profession.starter_items.is_empty():
		return -1
	var total := 0
	for raw_id in profession.starter_items:
		var item_id := StringName(str(raw_id))
		var raw_quantity: Variant = profession.starter_items[raw_id]
		if typeof(raw_quantity) not in [TYPE_INT, TYPE_FLOAT]:
			return -1
		var quantity := int(raw_quantity)
		if quantity <= 0 or not is_equal_approx(float(raw_quantity), float(quantity)):
			return -1
		var definition := ResourceRegistry.get_item(item_id)
		if definition == null or definition.starter_balance_value <= 0:
			return -1
		if definition.item_type in [ItemDefinition.ItemType.QUEST, ItemDefinition.ItemType.GIFT]:
			return -1
		total += definition.starter_balance_value * quantity
	return total


static func is_balanced(profession: ProfessionDefinition) -> bool:
	return calculate_value(profession) == TARGET_VALUE and _matches_default_items(profession)


static func grant(inventory: InventoryComponent, profession: ProfessionDefinition) -> bool:
	if inventory == null or not is_balanced(profession):
		return false
	return _grant_items(inventory, profession.starter_items)


static func grant_safe_default(inventory: InventoryComponent) -> bool:
	return _grant_items(inventory, DEFAULT_ITEMS)


static func _grant_items(inventory: InventoryComponent, items: Dictionary) -> bool:
	if inventory == null:
		return false
	var snapshot := inventory.to_dict()
	var item_ids: Array[StringName] = []
	for item_id in DEFAULT_ITEM_ORDER:
		if int(items.get(String(item_id), items.get(item_id, 0))) > 0:
			item_ids.append(item_id)
	var extra_ids: Array[String] = []
	for raw_id in items:
		var item_id := StringName(str(raw_id))
		if not item_ids.has(item_id):
			extra_ids.append(String(item_id))
	extra_ids.sort()
	for raw_id in extra_ids:
		item_ids.append(StringName(raw_id))
	for item_id in item_ids:
		var quantity := int(items.get(String(item_id), items.get(item_id, 0)))
		if inventory.add_item(item_id, quantity) != quantity:
			inventory.from_dict(snapshot)
			return false
	return true


static func _matches_default_items(profession: ProfessionDefinition) -> bool:
	if profession == null or profession.starter_items.size() != DEFAULT_ITEMS.size():
		return false
	for item_id in DEFAULT_ITEMS:
		var actual := int(profession.starter_items.get(
			item_id,
			profession.starter_items.get(StringName(item_id), 0),
		))
		if actual != int(DEFAULT_ITEMS[item_id]):
			return false
	return true
