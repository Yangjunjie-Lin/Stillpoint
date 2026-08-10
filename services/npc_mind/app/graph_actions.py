from __future__ import annotations

import re
from typing import Any


ACTION_PRIORITY = (
    "react_guard", "threaten", "recall", "point_route", "work", "demonstrate",
    "present_item", "thank", "salute", "reassure", "avoid", "inspect", "explain",
)


def annotate_graph_edge(edge: dict[str, Any], catalog: dict[str, Any]) -> dict[str, Any]:
    payload = dict(edge)
    categories = catalog.get("predicate_categories", {})
    category_id = str(categories.get(str(edge.get("predicate", "")), "uncategorized"))
    category = catalog.get("categories", {}).get(category_id, {})
    actions = catalog.get("actions", {})
    payload["relation_category"] = category_id
    payload["relation_color"] = str(category.get("color", "#95a5a6"))
    payload["reusable_actions"] = [
        {"action_id": action_id, **dict(actions.get(action_id, {}))}
        for action_id in category.get("actions", [])
        if action_id in actions
    ]
    return payload


def select_context_motion(
    player_text: str,
    graph: list[dict[str, Any]],
    catalog: dict[str, Any],
    requested_animation: str,
) -> str:
    """Select a presentation-only action from visible graph relation classes."""

    normalized = player_text.casefold()
    present_categories = {
        str(edge.get("relation_category", ""))
        for edge in graph
        if isinstance(edge, dict)
    }
    categories = catalog.get("categories", {})
    available_action_ids = {
        str(action_id)
        for category_id in present_categories
        for action_id in categories.get(category_id, {}).get("actions", [])
    }
    actions = catalog.get("actions", {})
    for action_id in ACTION_PRIORITY:
        if action_id not in available_action_ids:
            continue
        definition = actions.get(action_id, {})
        if any(str(term).casefold() in normalized for term in definition.get("trigger_terms", [])):
            return str(definition.get("motion_state", "talk"))
    allowed_motions = {
        str(definition.get("motion_state", ""))
        for definition in actions.values()
        if isinstance(definition, dict)
    }
    if requested_animation in allowed_motions:
        return requested_animation
    if requested_animation in actions:
        return str(actions[requested_animation].get("motion_state", "talk"))
    return "talk"


def build_graph_visualization(
    nodes: list[dict[str, Any]],
    edges: list[dict[str, Any]],
    catalog: dict[str, Any],
) -> dict[str, Any]:
    """Return renderer-ready category data plus a safe Mermaid graph drawing."""

    aliases = {str(node.get("node_id", "")): f"n{index}" for index, node in enumerate(nodes)}
    lines = ["flowchart LR"]
    for node in nodes:
        node_id = str(node.get("node_id", ""))
        label = _diagram_text(str(node.get("label") or node_id))
        node_type = _diagram_text(str(node.get("node_type", "concept")))
        lines.append(f'  {aliases[node_id]}["{label} - {node_type}"]')
    rendered_edges: list[dict[str, Any]] = []
    link_styles: list[str] = []
    for edge in edges:
        subject = str(edge.get("subject_node_id", ""))
        object_id = str(edge.get("object_node_id", ""))
        if subject not in aliases or object_id not in aliases:
            continue
        predicate = _diagram_text(str(edge.get("predicate", "RELATED_TO")))
        lines.append(f"  {aliases[subject]} -->|{predicate}| {aliases[object_id]}")
        color = str(edge.get("relation_color", "#95a5a6"))
        link_styles.append(f"  linkStyle {len(rendered_edges)} stroke:{color},stroke-width:2px")
        rendered_edges.append(
            {
                "subject_node_id": subject,
                "object_node_id": object_id,
                "predicate": str(edge.get("predicate", "")),
                "relation_category": str(edge.get("relation_category", "uncategorized")),
                "color": color,
                "action_ids": [
                    str(action.get("action_id", ""))
                    for action in edge.get("reusable_actions", [])
                ],
            }
        )
    lines.extend(link_styles)
    used_categories = {edge["relation_category"] for edge in rendered_edges}
    category_definitions = catalog.get("categories", {})
    legend = [
        {"category_id": category_id, **dict(category_definitions.get(category_id, {}))}
        for category_id in sorted(used_categories)
    ]
    return {
        "layout": "left_to_right",
        "legend": legend,
        "nodes": nodes,
        "edges": rendered_edges,
        "mermaid": "\n".join(lines),
    }


def _diagram_text(value: str) -> str:
    return re.sub(r"[\[\]{}()|\"<>]", " ", value).replace("\n", " ")[:120]
