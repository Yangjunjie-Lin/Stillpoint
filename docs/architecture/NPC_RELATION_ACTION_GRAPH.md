# NPC Relation and Reusable Action Graph

The server-owned cognition catalog classifies every canonical graph predicate.
Each class exposes presentation-only actions; it never executes gameplay intents.

```mermaid
flowchart LR
  KG["Scoped knowledge graph"] --> RC["Authored relation classifier"]
  RC --> SP["Spatial"]
  RC --> VO["Vocation"]
  RC --> SO["Social"]
  RC --> KN["Knowledge / belief"]
  RC --> ME["Memory / event"]
  RC --> CF["Conflict"]
  SP --> POINT["point / inspect"]
  VO --> WORK["work / explain"]
  SO --> TALK["talk / reassure / thank"]
  KN --> EXPLAIN["explain / recall"]
  ME --> RECALL["recall / guard"]
  CF --> GUARD["guard / threaten"]
  POINT --> MOTION["Reusable procedural motion rig"]
  WORK --> MOTION
  TALK --> MOTION
  EXPLAIN --> MOTION
  RECALL --> MOTION
  GUARD --> MOTION
```

The `/v1/npcs/{persistent_id}/graph` response includes category colors, reusable
actions, renderer-ready nodes and edges, and a scoped Mermaid representation.
