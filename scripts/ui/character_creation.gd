class_name CharacterCreationUI
extends Control
## New-adventure origin, faction and profession selection with a live 3D preview.

const ORIGIN_ORDER: Array[StringName] = [
	&"wuxia_swordsman",
	&"lotus_ascetic",
	&"ronin",
	&"oathbound_knight",
	&"dune_ranger",
	&"steppe_rider",
]
const FACTION_ORDER: Array[StringName] = [
	&"free_roads",
	&"dawn_covenant",
	&"verdant_circle",
	&"ash_watch",
]
const PROFESSION_ORDER: Array[StringName] = [
	&"spirit_blade",
	&"vow_keeper",
	&"duelist",
	&"guardian",
	&"pathfinder",
	&"wind_scout",
]
const BASE_STATS: Dictionary = {
	&"max_health": 120.0,
	&"max_energy": 100.0,
	&"attack": 0.0,
	&"defense": 0.0,
	&"move_speed": 4.0,
	&"energy_regen": 8.0,
}
const STAT_LABELS: Dictionary = {
	&"max_health_bonus": "生命上限",
	&"max_energy_bonus": "能量上限",
	&"attack_bonus": "攻击",
	&"defense_bonus": "防御",
	&"move_speed_bonus": "移动速度",
	&"energy_regen_bonus": "能量恢复",
}
const STARTER_ITEM_LABELS: Dictionary = {
	&"field_pick": "工具镐",
	&"padded_vest": "软甲",
	&"trail_snack": "行粮",
	&"training_sword": "练习剑",
	&"wanderer_charm": "旅人护符",
}

@onready var origin_list: ItemList = %OriginList
@onready var faction_list: ItemList = %FactionList
@onready var profession_list: ItemList = %ProfessionList
@onready var preview_model_root: Node3D = %PreviewModelRoot
@onready var origin_name_label: Label = %OriginNameLabel
@onready var origin_description_label: Label = %OriginDescriptionLabel
@onready var appearance_label: Label = %AppearanceLabel
@onready var selection_label: Label = %SelectionLabel
@onready var recommendation_label: Label = %RecommendationLabel
@onready var stats_label: Label = %StatsLabel
@onready var signature_label: Label = %SignatureLabel
@onready var starter_kit_label: Label = %StarterKitLabel
@onready var seed_label: Label = %SeedLabel
@onready var error_label: Label = %ErrorLabel
@onready var confirm_button: Button = %ConfirmButton
@onready var recommendation_button: Button = %RecommendationButton
@onready var reroll_button: Button = %RerollButton
@onready var body_option: OptionButton = %BodyOption
@onready var skin_option: OptionButton = %SkinOption
@onready var hair_option: OptionButton = %HairOption
@onready var headwear_option: OptionButton = %HeadwearOption
@onready var palette_option: OptionButton = %PaletteOption
@onready var accessory_option: OptionButton = %AccessoryOption

var _origins: Array[CharacterOriginDefinition] = []
var _factions: Array[FactionDefinition] = []
var _professions: Array[ProfessionDefinition] = []
var _origin_id: StringName = &""
var _faction_id: StringName = &""
var _profession_id: StringName = &""
var _preview_model: Node3D
var _appearance_options: Dictionary = CharacterAppearanceOptions.default_options()
var _attribute_seed: int = GameManager.DEFAULT_ATTRIBUTE_SEED
var _attribute_points: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_definitions()
	_populate_lists()
	_populate_customization_options()
	_connect_signals()
	_select_initial_build()
	_roll_attributes(false)
	_refresh_all()
	origin_list.call_deferred("grab_focus")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		GameManager.cancel_character_creation()
		get_viewport().set_input_as_handled()


func _load_definitions() -> void:
	for id in ORIGIN_ORDER:
		var origin := ResourceRegistry.get_origin(id)
		if origin != null:
			_origins.append(origin)
	for id in FACTION_ORDER:
		var faction := ResourceRegistry.get_faction(id)
		if faction != null and faction.selectable:
			_factions.append(faction)
	for id in PROFESSION_ORDER:
		var profession := ResourceRegistry.get_profession(id)
		if profession != null:
			_professions.append(profession)


func _populate_lists() -> void:
	origin_list.clear()
	for origin in _origins:
		origin_list.add_item(origin.display_name)
		var index := origin_list.item_count - 1
		origin_list.set_item_metadata(index, String(origin.id))
		origin_list.set_item_tooltip(index, origin.description)
	faction_list.clear()
	for faction in _factions:
		faction_list.add_item(faction.display_name)
		var index := faction_list.item_count - 1
		faction_list.set_item_metadata(index, String(faction.id))
		faction_list.set_item_tooltip(index, faction.description)
	profession_list.clear()
	for profession in _professions:
		profession_list.add_item(profession.display_name)
		var index := profession_list.item_count - 1
		profession_list.set_item_metadata(index, String(profession.id))
		profession_list.set_item_tooltip(index, profession.description)


func _populate_customization_options() -> void:
	_populate_option(body_option, CharacterAppearanceOptions.BODY_OPTIONS, &"balanced")
	_populate_option(skin_option, CharacterAppearanceOptions.SKIN_OPTIONS, &"origin")
	_populate_option(hair_option, CharacterAppearanceOptions.HAIR_OPTIONS, &"origin")
	_populate_option(headwear_option, CharacterAppearanceOptions.HEADWEAR_OPTIONS, &"origin")
	_populate_option(palette_option, CharacterAppearanceOptions.PALETTE_OPTIONS, &"origin")
	_populate_option(accessory_option, CharacterAppearanceOptions.ACCESSORY_OPTIONS, &"none")


func _populate_option(button: OptionButton, ids: Array[StringName], selected_id: StringName) -> void:
	button.clear()
	for id in ids:
		button.add_item(CharacterAppearanceOptions.label_for(id))
		var index := button.item_count - 1
		button.set_item_metadata(index, String(id))
		if id == selected_id:
			button.select(index)


func _connect_signals() -> void:
	if not origin_list.item_selected.is_connected(_on_origin_selected):
		origin_list.item_selected.connect(_on_origin_selected)
	if not faction_list.item_selected.is_connected(_on_faction_selected):
		faction_list.item_selected.connect(_on_faction_selected)
	if not profession_list.item_selected.is_connected(_on_profession_selected):
		profession_list.item_selected.connect(_on_profession_selected)
	if not recommendation_button.pressed.is_connected(_apply_recommended_build):
		recommendation_button.pressed.connect(_apply_recommended_build)
	if not confirm_button.pressed.is_connected(_confirm_build):
		confirm_button.pressed.connect(_confirm_build)
	if not reroll_button.pressed.is_connected(_on_reroll_pressed):
		reroll_button.pressed.connect(_on_reroll_pressed)
	if not body_option.item_selected.is_connected(_on_body_selected):
		body_option.item_selected.connect(_on_body_selected)
	if not skin_option.item_selected.is_connected(_on_skin_selected):
		skin_option.item_selected.connect(_on_skin_selected)
	if not hair_option.item_selected.is_connected(_on_hair_selected):
		hair_option.item_selected.connect(_on_hair_selected)
	if not headwear_option.item_selected.is_connected(_on_headwear_selected):
		headwear_option.item_selected.connect(_on_headwear_selected)
	if not palette_option.item_selected.is_connected(_on_palette_selected):
		palette_option.item_selected.connect(_on_palette_selected)
	if not accessory_option.item_selected.is_connected(_on_accessory_selected):
		accessory_option.item_selected.connect(_on_accessory_selected)
	var back_button := %BackButton as Button
	if not back_button.pressed.is_connected(GameManager.cancel_character_creation):
		back_button.pressed.connect(GameManager.cancel_character_creation)


func _select_initial_build() -> void:
	_select_origin(GameManager.DEFAULT_ORIGIN_ID)
	var origin := ResourceRegistry.get_origin(_origin_id)
	var faction_id := GameManager.DEFAULT_FACTION_ID
	var profession_id := GameManager.DEFAULT_PROFESSION_ID
	if origin != null:
		if origin.recommended_faction_id != &"":
			faction_id = origin.recommended_faction_id
		if origin.recommended_profession_id != &"":
			profession_id = origin.recommended_profession_id
	_select_faction(faction_id)
	_select_profession(profession_id)


func _select_origin(id: StringName) -> bool:
	for index in _origins.size():
		if _origins[index].id == id:
			origin_list.select(index)
			_origin_id = id
			return true
	return false


func _select_faction(id: StringName) -> bool:
	for index in _factions.size():
		if _factions[index].id == id:
			faction_list.select(index)
			_faction_id = id
			return true
	return false


func _select_profession(id: StringName) -> bool:
	for index in _professions.size():
		if _professions[index].id == id:
			profession_list.select(index)
			_profession_id = id
			return true
	return false


func _on_origin_selected(index: int) -> void:
	if index < 0 or index >= _origins.size():
		return
	_origin_id = _origins[index].id
	error_label.text = ""
	error_label.visible = false
	_refresh_all()


func _on_faction_selected(index: int) -> void:
	if index < 0 or index >= _factions.size():
		return
	_faction_id = _factions[index].id
	error_label.text = ""
	error_label.visible = false
	_refresh_all()


func _on_profession_selected(index: int) -> void:
	if index < 0 or index >= _professions.size():
		return
	_profession_id = _professions[index].id
	error_label.text = ""
	error_label.visible = false
	_refresh_all()


func _on_body_selected(index: int) -> void:
	_set_appearance_option("body_id", body_option, index)


func _on_skin_selected(index: int) -> void:
	_set_appearance_option("skin_id", skin_option, index)


func _on_hair_selected(index: int) -> void:
	_set_appearance_option("hair_id", hair_option, index)


func _on_headwear_selected(index: int) -> void:
	_set_appearance_option("headwear_id", headwear_option, index)


func _on_palette_selected(index: int) -> void:
	_set_appearance_option("palette_id", palette_option, index)


func _on_accessory_selected(index: int) -> void:
	_set_appearance_option("accessory_id", accessory_option, index)


func _set_appearance_option(key: String, button: OptionButton, index: int) -> void:
	if index < 0 or index >= button.item_count:
		return
	_appearance_options[key] = str(button.get_item_metadata(index))
	_appearance_options = CharacterAppearanceOptions.normalize(_appearance_options)
	_refresh_preview(ResourceRegistry.get_origin(_origin_id))


func _on_reroll_pressed() -> void:
	_roll_attributes(true)


func _roll_attributes(refresh: bool) -> void:
	_attribute_seed = CharacterBuildCalculator.create_seed(
		"%s:%d" % [GameManager.player_name, Time.get_ticks_usec()]
	)
	_attribute_points = CharacterBuildCalculator.roll_attribute_points(_attribute_seed)
	if refresh:
		_refresh_all()


func _apply_recommended_build() -> void:
	var origin := ResourceRegistry.get_origin(_origin_id)
	if origin == null:
		return
	_select_faction(origin.recommended_faction_id)
	_select_profession(origin.recommended_profession_id)
	_refresh_all()


func _confirm_build() -> void:
	if GameManager.confirm_character_build(
		_origin_id,
		_faction_id,
		_profession_id,
		_appearance_options,
		_attribute_seed,
	):
		return
	error_label.text = "请选择有效的出身、阵营和职业。"
	error_label.visible = true
	confirm_button.disabled = true


func _refresh_all() -> void:
	var origin := ResourceRegistry.get_origin(_origin_id)
	var faction := ResourceRegistry.get_faction(_faction_id)
	var profession := ResourceRegistry.get_profession(_profession_id)
	confirm_button.disabled = (
		origin == null or faction == null or not faction.selectable or profession == null
	)
	_refresh_preview(origin)
	_refresh_origin_details(origin)
	_refresh_recommendation(origin)
	_refresh_selection_and_stats(origin, faction, profession)
	_refresh_build_details(faction, profession)


func _refresh_preview(origin: CharacterOriginDefinition) -> void:
	if _preview_model != null:
		_preview_model.free()
		_preview_model = null
	if origin == null:
		return
	var model_scene := origin.model_scene
	if model_scene == null:
		model_scene = _load_origin_model_fallback(origin.id)
	if model_scene == null:
		return
	_preview_model = model_scene.instantiate() as Node3D
	if _preview_model == null:
		return
	if _preview_model is StylizedHeroModel:
		var hero := _preview_model as StylizedHeroModel
		hero.preview_idle_motion = true
		hero.apply_customization(_appearance_options)
	preview_model_root.add_child(_preview_model)


func _refresh_origin_details(origin: CharacterOriginDefinition) -> void:
	if origin == null:
		origin_name_label.text = "尚未选择出身"
		origin_description_label.text = ""
		appearance_label.text = ""
		return
	origin_name_label.text = origin.display_name
	origin_name_label.modulate = origin.accent_color.lightened(0.2)
	origin_description_label.text = origin.description
	appearance_label.text = "造型：%s" % origin.appearance_description


func _refresh_recommendation(origin: CharacterOriginDefinition) -> void:
	if origin == null:
		recommendation_label.text = ""
		recommendation_button.disabled = true
		return
	var faction := ResourceRegistry.get_faction(origin.recommended_faction_id)
	var profession := ResourceRegistry.get_profession(origin.recommended_profession_id)
	if faction == null or profession == null:
		recommendation_label.text = "所有阵营与职业均可自由组合。"
		recommendation_button.disabled = true
		return
	recommendation_label.text = "推荐：%s · %s\n仅为玩法建议，不限制选择。" % [
		faction.display_name,
		profession.display_name,
	]
	recommendation_button.disabled = false


func _refresh_selection_and_stats(
	origin: CharacterOriginDefinition,
	faction: FactionDefinition,
	profession: ProfessionDefinition,
) -> void:
	selection_label.text = "出身  %s\n阵营  %s\n职业  %s" % [
		origin.display_name if origin != null else "—",
		faction.display_name if faction != null else "—",
		profession.display_name if profession != null else "—",
	]
	if origin == null or faction == null or profession == null:
		stats_label.text = "完成三项选择后显示属性。"
		return
	var bonuses := CharacterBuildCalculator.calculate_bonuses(
		origin,
		faction,
		profession,
		_attribute_points,
	)
	var stats := CharacterBuildCalculator.apply_bonuses(BASE_STATS, bonuses)
	var physical_strength := CharacterBuildCalculator.physical_strength_from_bonuses(
		bonuses
	)
	stats_label.text = (
		"生命      %d  (%s)\n"
		+ "能量      %d  (%s)\n"
		+ "力量      %d\n"
		+ "伤害加成  %s\n"
		+ "防御      %.1f  (%s)\n"
		+ "移动      %.2f  (%s)\n"
		+ "能量恢复  %.2f  (%s)"
	) % [
		int(round(float(stats[&"max_health"]))),
		_format_bonus(float(bonuses[&"max_health_bonus"])),
		int(round(float(stats[&"max_energy"]))),
		_format_bonus(float(bonuses[&"max_energy_bonus"])),
		physical_strength,
		_format_bonus(float(stats[&"attack"])),
		float(stats[&"defense"]),
		_format_bonus(float(bonuses[&"defense_bonus"])),
		float(stats[&"move_speed"]),
		_format_bonus(float(bonuses[&"move_speed_bonus"])),
		float(stats[&"energy_regen"]),
		_format_bonus(float(bonuses[&"energy_regen_bonus"])),
	]


func _refresh_build_details(
	faction: FactionDefinition,
	profession: ProfessionDefinition,
) -> void:
	seed_label.text = "属性种子  %d  ·  固定 %d 点随机预算" % [
		_attribute_seed,
		CharacterBuildCalculator.RANDOM_POINT_BUDGET,
	]
	if faction == null or profession == null:
		signature_label.text = ""
		starter_kit_label.text = ""
		return
	var faction_key := CharacterBuildCalculator.signature_bonus_key(faction)
	var profession_key := CharacterBuildCalculator.signature_bonus_key(profession)
	signature_label.text = "阵营特重  %s（%d 点）\n职业特重  %s（%d 点）" % [
		str(STAT_LABELS.get(faction_key, "—")),
		CharacterBuildCalculator.signature_point_count(faction),
		str(STAT_LABELS.get(profession_key, "—")),
		CharacterBuildCalculator.signature_point_count(profession),
	]
	var item_parts: Array[String] = []
	var ids: Array[String] = []
	for raw_id in profession.starter_items:
		ids.append(str(raw_id))
	ids.sort()
	for raw_id in ids:
		var definition := ResourceRegistry.get_item(StringName(raw_id))
		var quantity := int(profession.starter_items.get(raw_id, 0))
		if definition != null and quantity > 0:
			item_parts.append("%s×%d" % [
				str(STARTER_ITEM_LABELS.get(definition.id, definition.display_name)),
				quantity,
			])
	starter_kit_label.text = "初始资源（价值 %d/%d）\n%s" % [
		StarterKitCalculator.calculate_value(profession),
		StarterKitCalculator.TARGET_VALUE,
		" · ".join(item_parts),
	]


func _format_bonus(value: float) -> String:
	if is_zero_approx(value):
		return "±0"
	return "%+.2f" % value


func _load_origin_model_fallback(origin_id: StringName) -> PackedScene:
	var path := "res://scenes/characters/player/origins/%s.tscn" % String(origin_id)
	return load(path) as PackedScene
