class_name CommerceMenu
extends Control
## Modal shop/forge surface backed by transactional CommerceService operations.

@onready var title_label: Label = %Title
@onready var funds_label: Label = %Funds
@onready var shop_description_label: Label = %ShopDescription
@onready var offers_list: ItemList = %OffersList
@onready var inventory_list: ItemList = %InventoryList
@onready var sell_button: Button = %SellButton
@onready var forge_box: Control = %ForgeBox
@onready var recipes_list: ItemList = %RecipesList
@onready var status_label: Label = %Status

var _world: WorldSession
var _player: PlayerController3D
var _funds: PropertyBankService
var _commerce := CommerceService.new()
var _shop_id: StringName = &""
var _recipe_ids: Array[StringName] = []
var _tree_was_paused := false
var _player_input_was_enabled := true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	call_deferred("_bind_world")


func _exit_tree() -> void:
	if visible and get_tree() != null:
		get_tree().paused = _tree_was_paused


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"pause"):
		close_menu()
		get_viewport().set_input_as_handled()


func open_menu(shop_id: StringName, recipe_ids: Array[StringName] = []) -> void:
	_bind_world()
	var shop := ResourceRegistry.get_shop(shop_id)
	if visible or shop == null or _player == null or _player.inventory == null or _funds == null:
		return
	_shop_id = shop_id
	_recipe_ids = recipe_ids.duplicate()
	_tree_was_paused = get_tree().paused
	_player_input_was_enabled = _player.state.input_enabled
	_player.set_input_enabled(false)
	get_tree().paused = true
	visible = true
	status_label.text = ""
	_refresh()


func close_menu() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = _tree_was_paused
	if _player != null:
		_player.set_input_enabled(_player_input_was_enabled)


func is_open() -> bool:
	return visible


func _bind_world() -> void:
	_world = _find_world()
	if _world == null or _world.player == null:
		return
	_player = _world.player
	_funds = _world.property_bank_service
	if _player.inventory != null and not _player.inventory.inventory_changed.is_connected(_refresh):
		_player.inventory.inventory_changed.connect(_refresh)
	if _funds != null and not _funds.property_state_changed.is_connected(_refresh):
		_funds.property_state_changed.connect(_refresh)


func _refresh() -> void:
	if not visible or _player == null or _funds == null:
		return
	var shop := ResourceRegistry.get_shop(_shop_id)
	if shop == null:
		close_menu()
		return
	title_label.text = shop.display_name
	shop_description_label.text = shop.public_description
	funds_label.text = "Wallet %d    Bank %d    Available %d coin" % [
		_funds.wallet_balance,
		_funds.bank_balance,
		_funds.get_total_funds(),
	]
	_populate_offers(shop)
	_populate_inventory(shop)
	_populate_recipes()


func _populate_offers(shop: ShopDefinition) -> void:
	var previous := _selected_metadata(offers_list)
	offers_list.clear()
	for offer in shop.offers:
		if offer == null:
			continue
		var item := ResourceRegistry.get_item(offer.item_id)
		if item == null:
			continue
		var price := offer.resolved_unit_price(item) * offer.quantity_per_purchase
		var row := offers_list.add_item("%s x%d    %d coin" % [
			item.display_name, offer.quantity_per_purchase, price,
		])
		offers_list.set_item_metadata(row, String(offer.id))
		if previous == String(offer.id):
			offers_list.select(row)


func _populate_inventory(shop: ShopDefinition) -> void:
	var previous := _selected_metadata(inventory_list)
	inventory_list.clear()
	for slot_index in _player.inventory.slot_count:
		var stack := _player.inventory.get_slot(slot_index)
		if stack == null or stack.is_empty():
			continue
		var item := ResourceRegistry.get_item(stack.item_id)
		if item == null:
			continue
		var row := inventory_list.add_item("%s x%d    sell %d" % [
			item.display_name, stack.quantity, item.sell_price,
		])
		inventory_list.set_item_metadata(row, String(stack.item_id))
		inventory_list.set_item_disabled(row, not shop.buys_from_player or item.sell_price <= 0)
		if previous == String(stack.item_id):
			inventory_list.select(row)
	sell_button.visible = shop.buys_from_player


func _populate_recipes() -> void:
	var previous := _selected_metadata(recipes_list)
	recipes_list.clear()
	for recipe_id in _recipe_ids:
		var recipe := ResourceRegistry.get_forge_recipe(recipe_id)
		if recipe == null:
			continue
		var output := ResourceRegistry.get_item(recipe.output_item_id)
		var parts: Array[String] = []
		for item_id in recipe.normalized_ingredients().keys():
			var item := ResourceRegistry.get_item(item_id)
			parts.append("%s x%d" % [
				item.display_name if item != null else String(item_id),
				recipe.ingredient_quantity(item_id),
			])
		var row := recipes_list.add_item("%s | LV %d | %s | fee %d" % [
			output.display_name if output != null else recipe.display_name,
			recipe.required_level,
			", ".join(parts),
			recipe.service_fee,
		])
		recipes_list.set_item_metadata(row, String(recipe.id))
		if previous == String(recipe.id):
			recipes_list.select(row)
	forge_box.visible = recipes_list.item_count > 0


func _on_buy_pressed() -> void:
	var offer_id := StringName(_selected_metadata(offers_list))
	var result := _commerce.buy(_shop_id, offer_id, 1, _player.inventory, _funds)
	_show_result(result)


func _on_sell_pressed() -> void:
	var item_id := StringName(_selected_metadata(inventory_list))
	var result := _commerce.sell(_shop_id, item_id, 1, _player.inventory, _funds)
	_show_result(result)


func _on_forge_pressed() -> void:
	var recipe_id := StringName(_selected_metadata(recipes_list))
	var result := _commerce.forge(
		recipe_id, 1, _player.inventory, _funds, _player.get_combat_level()
	)
	_show_result(result)


func _show_result(result: Dictionary) -> void:
	var code := String(result.get("code", "invalid_request"))
	if bool(result.get("success", false)):
		status_label.text = {
			"purchased": "Purchase completed.",
			"sold": "Item sold and proceeds added to your wallet.",
			"forged": "Forging completed; the new equipment is in your backpack.",
		}.get(code, "Transaction completed.")
	else:
		status_label.text = {
			"invalid_request": "Select an available entry first.",
			"insufficient_funds": "Insufficient wallet and bank funds.",
			"inventory_full": "Your backpack has no room for this transaction.",
			"insufficient_items": "You do not have enough of that item.",
			"insufficient_materials": "Required forging materials are missing.",
			"level_too_low": "Your combat level is too low for this recipe.",
			"shop_does_not_buy": "This counter does not buy items.",
			"not_sellable": "That item cannot be sold.",
		}.get(code, "Transaction unavailable: %s." % code.replace("_", " "))
	_refresh()


func _selected_metadata(list: ItemList) -> String:
	var selected := list.get_selected_items()
	if selected.is_empty():
		return ""
	return str(list.get_item_metadata(selected[0]))


func _find_world() -> WorldSession:
	var node := get_parent()
	while node != null:
		if node is WorldSession:
			return node as WorldSession
		node = node.get_parent()
	return get_tree().get_first_node_in_group("world_manager") as WorldSession
