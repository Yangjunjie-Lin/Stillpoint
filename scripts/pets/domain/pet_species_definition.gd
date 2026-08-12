class_name PetSpeciesDefinition
extends Resource
## Canonical ontology node for a pet species. Individual personality and
## mutable condition deliberately live elsewhere.

@export var id: StringName = &"pet_species"
@export var display_name: String = "Pet Species"
@export_multiline var description: String = ""
@export var species_tags: Array[StringName] = []
@export var habitat_tags: Array[StringName] = []
@export var preferred_food_tags: Array[StringName] = []
@export var visual_archetype: StringName = &"quadruped"
@export var coat_color: Color = Color("8d6747")
@export var coat_light_color: Color = Color("d5b47f")
@export var accent_color: Color = Color("5f8b68")
@export_range(0.5, 2.0, 0.05) var visual_scale: float = 1.0
@export_range(1.0, 10000.0, 1.0) var base_max_health: float = 40.0
@export_range(1.0, 10000.0, 1.0) var base_max_stamina: float = 60.0
@export_range(0.0, 1000.0, 0.1) var natural_defense: float = 0.0
@export_range(0.0, 100.0, 0.1) var health_gain_per_level: float = 4.0
@export_range(0.0, 100.0, 0.1) var stamina_gain_per_level: float = 3.0
@export_range(0.0, 20.0, 0.01) var hunger_per_game_hour: float = 1.0
@export_range(0.0, 100.0, 0.1) var rest_stamina_per_game_hour: float = 8.0

const SUPPORTED_VISUAL_ARCHETYPES: Array[StringName] = [
	&"quadruped",
	&"mossfox",
	&"stonehound",
	&"cloudowl",
]


func is_valid() -> bool:
	return (
		id != &""
		and not display_name.strip_edges().is_empty()
		and SUPPORTED_VISUAL_ARCHETYPES.has(visual_archetype)
		and visual_scale >= 0.5
		and visual_scale <= 2.0
		and base_max_health > 0.0
		and base_max_stamina > 0.0
		and natural_defense >= 0.0
		and hunger_per_game_hour >= 0.0
	)


func ontology_node_id() -> StringName:
	var raw := String(id)
	return id if raw.begins_with("pet_species:") \
		else StringName("pet_species:%s" % raw)


func to_catalog_dict() -> Dictionary:
	return {
		"node_id": String(ontology_node_id()),
		"node_type": "pet_species",
		"label": display_name,
		"metadata": {
			"definition_id": String(id),
			"description": description,
			"species_tags": _strings(species_tags),
			"habitat_tags": _strings(habitat_tags),
			"preferred_food_tags": _strings(preferred_food_tags),
			"visual_archetype": String(visual_archetype),
			"visual_scale": visual_scale,
			"base_max_health": base_max_health,
			"base_max_stamina": base_max_stamina,
			"natural_defense": natural_defense,
		},
	}


func _strings(values: Array[StringName]) -> Array[String]:
	var result: Array[String] = []
	for value in values:
		result.append(String(value))
	return result
