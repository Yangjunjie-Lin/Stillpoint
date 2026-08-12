from app.catalog import NpcCatalogRepository
from app.graph import CANONICAL_WORLD_EDGE_TYPES, EDGE_TYPES, NODE_TYPES


def _ontology() -> tuple[dict[str, dict], set[tuple[str, str, str]]]:
    ontology = NpcCatalogRepository().world_ontology
    nodes = {node["node_id"]: node for node in ontology["nodes"]}
    edges = {
        (edge["subject_node_id"], edge["predicate"], edge["object_node_id"])
        for edge in ontology["edges"]
    }
    return nodes, edges


def test_bank_and_blacksmith_shops_are_authored_public_ontology():
    nodes, edges = _ontology()

    bank = nodes["shop:stillpoint_bank_equipment"]
    smithy = nodes["shop:stillpoint_blacksmith_equipment"]
    assert bank["node_type"] == "shop"
    assert bank["metadata"]["buys_from_player"] is True
    assert smithy["node_type"] == "shop"
    assert smithy["metadata"]["shop_type"] == "blacksmith_equipment"
    assert (
        "shop:stillpoint_bank_equipment",
        "LOCATED_IN",
        "building:stillpoint_bank",
    ) in edges
    assert (
        "shop:stillpoint_bank_equipment",
        "OPERATED_BY",
        "npc_definition:bank_clerk",
    ) in edges
    assert (
        "shop:stillpoint_blacksmith_equipment",
        "OPERATED_BY",
        "npc_definition:blacksmith",
    ) in edges
    assert (
        "shop:stillpoint_bank_equipment",
        "OFFERS",
        "shop_offer:stillpoint_bank_equipment/training_sword",
    ) in edges
    assert (
        "shop_offer:stillpoint_bank_equipment/training_sword",
        "SELLS",
        "item:training_sword",
    ) in edges
    assert (
        "shop:stillpoint_blacksmith_equipment",
        "SELLS",
        "item:field_pick",
    ) in edges


def test_greywake_recipe_has_static_forge_relationships_and_quantities():
    nodes, edges = _ontology()

    recipe = nodes["forge:greywake_iron_sword"]
    assert recipe["node_type"] == "forge_recipe"
    assert recipe["metadata"]["required_level"] == 2
    assert recipe["metadata"]["service_fee"] == 85
    assert recipe["metadata"]["input_items"] == [
        {"item_node_id": "item:iron_ore", "quantity": 3},
        {"item_node_id": "item:training_sword", "quantity": 1},
    ]
    assert (
        "forge:greywake_iron_sword",
        "AVAILABLE_AT",
        "building:stillpoint_blacksmith",
    ) in edges
    assert (
        "forge:greywake_iron_sword",
        "PERFORMED_BY",
        "npc_definition:blacksmith",
    ) in edges
    assert (
        "forge:greywake_iron_sword",
        "REQUIRES_MATERIAL",
        "item:iron_ore",
    ) in edges
    assert (
        "forge:greywake_iron_sword",
        "REQUIRES_MATERIAL",
        "item:training_sword",
    ) in edges
    assert (
        "forge:greywake_iron_sword",
        "PRODUCES",
        "item:forged_iron_sword",
    ) in edges


def test_commerce_relations_are_canonical_and_private_finances_are_not_exported():
    nodes, edges = _ontology()
    commerce_types = {"shop", "shop_offer", "forge_recipe"}
    commerce_predicates = {
        "OPERATED_BY",
        "OFFERS",
        "SELLS",
        "AVAILABLE_AT",
        "PERFORMED_BY",
        "REQUIRES_MATERIAL",
    }
    assert commerce_types <= NODE_TYPES
    assert commerce_predicates <= EDGE_TYPES
    assert commerce_predicates <= CANONICAL_WORLD_EDGE_TYPES
    assert all(edge[1] in EDGE_TYPES for edge in edges)

    rendered = str(NpcCatalogRepository().world_ontology).lower()
    for private_field in (
        "wallet_balance",
        "home_cash_balance",
        "bank_balance",
        "investment_principal",
        "investment_earnings",
        "last_interest_day",
        "player_profile_id",
        "world_save_id",
    ):
        assert private_field not in rendered
