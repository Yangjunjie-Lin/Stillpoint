import pytest

from app.config import Settings
from app.repository import InMemoryRepository
from app.service import NpcCognitionService


def test_embedding_dimension_mismatch_is_rejected_at_startup():
    with pytest.raises(ValueError, match="embedding_dimension_must_match_schema"):
        NpcCognitionService(
            settings=Settings(app_env="test", embedding_dimensions=3072),
            repository=InMemoryRepository(),
        )
