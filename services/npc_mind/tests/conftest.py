import sys
import os
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parents[1]))


@pytest.fixture
def postgres_url() -> str:
    value = os.getenv("NPC_TEST_DATABASE_URL", "")
    if not value:
        pytest.skip("NPC_TEST_DATABASE_URL is required for PostgreSQL integration tests")
    return value
