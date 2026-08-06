from __future__ import annotations

import math
import re
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any


def recency(age_hours: float, half_life_hours: float) -> float:
    if half_life_hours <= 0:
        return 0.0
    return math.exp(-math.log(2.0) * max(age_hours, 0.0) / half_life_hours)


def lexical_similarity(query: str, text: str) -> float:
    q = {token for token in re.findall(r"[\w-]+", query.lower()) if len(token) > 1}
    t = {token for token in re.findall(r"[\w-]+", text.lower()) if len(token) > 1}
    if not q or not t:
        return 0.0
    return len(q & t) / len(q | t)


@dataclass(slots=True)
class MemoryRecord:
    memory_id: str
    player_profile_id: str
    world_save_id: str
    owner_npc_persistent_id: str
    session_id: str
    memory_type: str
    content: str
    summary: str = ""
    embedding: list[float] = field(default_factory=list)
    occurred_at_game: dict[str, Any] = field(default_factory=dict)
    created_at_real: str = field(default_factory=lambda: datetime.now(timezone.utc).isoformat())
    last_recalled_at: str | None = None
    recall_count: int = 0
    salience: float = 0.5
    emotional_valence: float = 0.0
    confidence: float = 0.7
    retention_strength: float = 1.0
    half_life_hours: float = 168.0
    source_type: str = "conversation_turn"
    source_id: str = ""
    subject_node_ids: list[str] = field(default_factory=list)
    visibility: str = "private"
    archived: bool = False
    supersedes_memory_id: str | None = None

    def to_dict(self) -> dict[str, Any]:
        return {name: getattr(self, name) for name in self.__dataclass_fields__}

    @classmethod
    def from_dict(cls, value: dict[str, Any]) -> "MemoryRecord":
        allowed = {name for name in cls.__dataclass_fields__}
        return cls(**{key: val for key, val in value.items() if key in allowed})

    def score(self, query: str, now: datetime | None = None) -> float:
        now = now or datetime.now(timezone.utc)
        created = _parse_time(self.created_at_real)
        age = max(0.0, (now - created).total_seconds() / 3600.0)
        similarity = lexical_similarity(query, f"{self.content} {self.summary}")
        current_recency = recency(age, self.half_life_hours)
        reinforcement = min(1.0, self.recall_count / 5.0) * self.retention_strength
        return (
            similarity * 0.40
            + self.salience * 0.15
            + self.confidence * 0.10
            + current_recency * 0.10
            + reinforcement * 0.05
        )


def _parse_time(value: str) -> datetime:
    try:
        result = datetime.fromisoformat(value.replace("Z", "+00:00"))
        return result if result.tzinfo else result.replace(tzinfo=timezone.utc)
    except ValueError:
        return datetime.now(timezone.utc)


def reinforce(record: MemoryRecord) -> None:
    record.last_recalled_at = datetime.now(timezone.utc).isoformat()
    record.recall_count += 1
    record.retention_strength = min(2.0, record.retention_strength + 0.05)


def consolidate(records: list[MemoryRecord]) -> list[MemoryRecord]:
    """Deduplicate without deleting evidence; preserve the strongest record."""
    by_signature: dict[tuple[str, str], MemoryRecord] = {}
    for record in records:
        signature = (record.memory_type, (record.summary or record.content).strip().lower())
        current = by_signature.get(signature)
        if current is None or (record.salience, record.confidence) > (
            current.salience,
            current.confidence,
        ):
            by_signature[signature] = record
    return list(by_signature.values())
