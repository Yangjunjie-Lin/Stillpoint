class_name InventorySlotButton
extends Button
## Reusable inventory/equipment slot surface with drag-and-drop delegation.

var inventory_menu: Control
var slot_kind: StringName = &"inventory"
var slot_index: int = -1
var equipment_slot: StringName = &""
var _icon_rect: TextureRect
var _heading_label: Label
var _name_label: Label
var _quantity_label: Label


func configure(
	menu: Control,
	kind: StringName,
	index: int = -1,
	equip_slot: StringName = &"",
) -> void:
	inventory_menu = menu
	slot_kind = kind
	slot_index = index
	equipment_slot = equip_slot
	_ensure_visual_nodes()


func set_compact_visual(
	heading: String,
	item_texture: Texture2D,
	quantity: int,
	fallback_text: String = "",
) -> void:
	_ensure_visual_nodes()
	text = ""
	icon = null
	_heading_label.text = heading
	_heading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_heading_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_heading_label.offset_left = 7.0
	_heading_label.offset_top = 3.0
	_heading_label.offset_right = -5.0
	_heading_label.offset_bottom = 22.0
	_icon_rect.texture = item_texture
	_icon_rect.visible = item_texture != null
	_icon_rect.set_anchors_preset(Control.PRESET_CENTER)
	_icon_rect.offset_left = -20.0
	_icon_rect.offset_top = -17.0
	_icon_rect.offset_right = 20.0
	_icon_rect.offset_bottom = 23.0
	_name_label.visible = item_texture == null
	_name_label.text = fallback_text
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.set_anchors_preset(Control.PRESET_CENTER)
	_name_label.offset_left = -31.0
	_name_label.offset_top = -14.0
	_name_label.offset_right = 31.0
	_name_label.offset_bottom = 20.0
	_quantity_label.text = "×%d" % quantity if quantity > 0 else ""
	_quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_quantity_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_quantity_label.offset_left = -42.0
	_quantity_label.offset_top = -22.0
	_quantity_label.offset_right = -5.0
	_quantity_label.offset_bottom = -3.0


func set_equipment_visual(
	heading: String,
	item_name: String,
	item_texture: Texture2D,
) -> void:
	_ensure_visual_nodes()
	text = ""
	icon = null
	_heading_label.text = heading
	_heading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_heading_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_heading_label.offset_left = 64.0
	_heading_label.offset_top = 7.0
	_heading_label.offset_right = -7.0
	_heading_label.offset_bottom = 28.0
	_icon_rect.texture = item_texture
	_icon_rect.visible = item_texture != null
	_icon_rect.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_icon_rect.offset_left = 10.0
	_icon_rect.offset_top = -22.0
	_icon_rect.offset_right = 54.0
	_icon_rect.offset_bottom = 22.0
	_name_label.visible = true
	_name_label.text = item_name if not item_name.is_empty() else "Empty"
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_name_label.offset_left = 64.0
	_name_label.offset_top = 29.0
	_name_label.offset_right = -7.0
	_name_label.offset_bottom = 61.0
	_quantity_label.text = ""


func _get_drag_data(_at_position: Vector2) -> Variant:
	if inventory_menu == null or not inventory_menu.has_method("get_slot_drag_data"):
		return null
	var payload: Variant = inventory_menu.call("get_slot_drag_data", self)
	if typeof(payload) != TYPE_DICTIONARY or (payload as Dictionary).is_empty():
		return null
	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(52.0, 52.0)
	preview.texture = _icon_rect.texture
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_drag_preview(preview)
	return payload


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return inventory_menu != null \
		and inventory_menu.has_method("can_drop_slot_data") \
		and bool(inventory_menu.call("can_drop_slot_data", self, data))


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if inventory_menu != null and inventory_menu.has_method("drop_slot_data"):
		inventory_menu.call("drop_slot_data", self, data)


func _ensure_visual_nodes() -> void:
	if _icon_rect != null:
		return
	clip_contents = true
	_icon_rect = TextureRect.new()
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon_rect)
	_heading_label = Label.new()
	_heading_label.add_theme_font_size_override("font_size", 11)
	_heading_label.add_theme_color_override("font_color", Color("5a3c1b"))
	_heading_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_heading_label)
	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 14)
	_name_label.add_theme_color_override("font_color", Color("362310"))
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)
	_quantity_label = Label.new()
	_quantity_label.add_theme_font_size_override("font_size", 13)
	_quantity_label.add_theme_color_override("font_color", Color("2f2111"))
	_quantity_label.add_theme_color_override("font_shadow_color", Color(1, 0.94, 0.7, 0.9))
	_quantity_label.add_theme_constant_override("shadow_offset_x", 1)
	_quantity_label.add_theme_constant_override("shadow_offset_y", 1)
	_quantity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_quantity_label)
