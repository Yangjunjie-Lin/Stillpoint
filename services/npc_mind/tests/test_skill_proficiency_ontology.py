from app.catalog import NpcCatalogRepository


def test_gameplay_skill_ontology_has_practice_limits_tools_and_recovery():
    ontology = NpcCatalogRepository().world_ontology
    nodes = {node["node_id"]: node for node in ontology["nodes"]}
    edges = {
        (edge["subject_node_id"], edge["predicate"], edge["object_node_id"])
        for edge in ontology["edges"]
    }

    soil = nodes["skill:soilworking"]
    assert soil["node_type"] == "skill"
    assert soil["metadata"]["daily_gain_cap"] == 9.0
    assert soil["metadata"]["context_recovery_days"] == 2
    assert soil["metadata"]["overtraining_threshold"] == 8
    assert "points" not in soil["metadata"]
    assert "player_id" not in soil["metadata"]
    assert (
        "skill:soilworking",
        "BELONGS_TO",
        "concept:skill_domain_life",
    ) in edges
    assert (
        "skill:soilworking",
        "PRACTICED_WITH",
        "item:field_pick",
    ) in edges
    assert (
        "skill:soilworking",
        "PRACTICED_BY",
        "concept:practice_action_till_soil",
    ) in edges
    assert (
        "skill:soilworking",
        "RECOVERS_AFTER",
        "concept:practice_recovery_2_days",
    ) in edges
    assert (
        "skill:soilworking",
        "SYNERGIZES_WITH",
        "skill:crop_cultivation",
    ) in edges


def test_skill_catalog_covers_combat_life_exploration_and_social_domains():
    ontology = NpcCatalogRepository().world_ontology
    skill_nodes = [node for node in ontology["nodes"] if node["node_type"] == "skill"]
    categories = {node["metadata"].get("category") for node in skill_nodes}

    assert len(skill_nodes) >= 16
    assert {"combat", "life", "exploration", "social"} <= categories
