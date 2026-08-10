from __future__ import annotations

import importlib.util
from pathlib import Path
from unittest.mock import patch


def _runner_module():
    path = (
        Path(__file__).parents[3]
        / "tools"
        / "python"
        / "run_npc_cognition_cross_process_e2e.py"
    )
    spec = importlib.util.spec_from_file_location("npc_cross_process_runner", path)
    assert spec is not None and spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_health_probe_treats_windows_connection_reset_as_backend_down():
    runner = _runner_module()
    with patch.object(
        runner.urllib.request,
        "urlopen",
        side_effect=ConnectionResetError("backend stopped"),
    ):
        assert runner._health_ready(18443) is False
