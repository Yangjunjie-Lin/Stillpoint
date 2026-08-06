from .test_graph_boundaries import (
    test_belief_graph_is_scoped_and_private_canonical_fact_is_not_public,
)


def test_visibility_filters_private_canonical_facts():
    test_belief_graph_is_scoped_and_private_canonical_fact_is_not_public()
