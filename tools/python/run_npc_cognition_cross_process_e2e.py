"""Run Godot -> HTTP -> Uvicorn -> PostgreSQL NPC cognition acceptance."""

from __future__ import annotations

import argparse
import os
import secrets
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
import uuid
from contextlib import suppress
from pathlib import Path

import psycopg
from psycopg import sql
from sqlalchemy.engine import URL, make_url


REPO_ROOT = Path(__file__).resolve().parents[2]
BACKEND_ROOT = REPO_ROOT / "services" / "npc_mind"
ARTIFACT_ROOT = REPO_ROOT / "artifacts" / "npc-cognition-cross-process-e2e"
PHASES = ("seed", "recall", "offline", "flush")
FORBIDDEN_LOG_MARKERS = (
    "Authorization: Bearer",
    "OPENAI_API_KEY=",
    "NPC_MIND_SIGNING_KEY=",
    "X-Client-Secret:",
)


class AcceptanceFailure(RuntimeError):
    pass


def _log(message: str) -> None:
    print(f"[npc-e2e] {message}", flush=True)


def _command(
    command: list[str],
    *,
    cwd: Path,
    env: dict[str, str] | None = None,
    log_path: Path | None = None,
    timeout: int = 180,
) -> None:
    _log(f"run: {command[0]} {command[1] if len(command) > 1 else ''}".rstrip())
    if log_path is None:
        result = subprocess.run(command, cwd=cwd, env=env, timeout=timeout, check=False)
    else:
        with log_path.open("w", encoding="utf-8", newline="\n") as output:
            result = subprocess.run(
                command,
                cwd=cwd,
                env=env,
                stdout=output,
                stderr=subprocess.STDOUT,
                timeout=timeout,
                check=False,
            )
    if result.returncode != 0:
        raise AcceptanceFailure(f"command failed with exit code {result.returncode}")


def _wait_for_database(database_url: str, timeout: float = 60.0) -> None:
    deadline = time.monotonic() + timeout
    last_error: Exception | None = None
    while time.monotonic() < deadline:
        try:
            with psycopg.connect(_psycopg_url(database_url), connect_timeout=2):
                return
        except psycopg.Error as error:
            last_error = error
            time.sleep(0.5)
    raise AcceptanceFailure("PostgreSQL did not become ready") from last_error


def _health_ready(port: int) -> bool:
    try:
        with urllib.request.urlopen(f"http://127.0.0.1:{port}/health", timeout=1) as response:
            return response.status == 200
    # Windows may reset the socket while Uvicorn is completing a graceful
    # shutdown. That is the expected "not healthy" state, not an E2E failure.
    except OSError:
        return False


def _wait_for_health(port: int, timeout: float = 30.0) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if _health_ready(port):
            return
        time.sleep(0.2)
    raise AcceptanceFailure("Uvicorn health endpoint did not become ready")


def _wait_for_health_down(port: int, timeout: float = 10.0) -> None:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if not _health_ready(port):
            return
        time.sleep(0.2)
    raise AcceptanceFailure("Uvicorn remained reachable after shutdown")


def _start_backend(
    database_url: str, port: int, signing_key: str, index: int
) -> tuple[subprocess.Popen[str], object]:
    log_path = ARTIFACT_ROOT / f"backend-{index}.log"
    log_handle = log_path.open("w", encoding="utf-8", newline="\n")
    env = os.environ.copy()
    env.update(
        {
            "APP_ENV": "test",
            "AUTH_MODE": "local_loopback",
            "NPC_REPOSITORY": "postgres",
            "DATABASE_URL": database_url,
            "NPC_MIND_SIGNING_KEY": signing_key,
            "LLM_PROVIDER": "fake",
            "NPC_EMBEDDING_DIMENSIONS": "1536",
            "PYTHONUNBUFFERED": "1",
        }
    )
    process = subprocess.Popen(
        [
            sys.executable,
            "-m",
            "uvicorn",
            "app.main:app",
            "--host",
            "127.0.0.1",
            "--port",
            str(port),
            "--log-level",
            "info",
            "--no-access-log",
        ],
        cwd=BACKEND_ROOT,
        env=env,
        stdout=log_handle,
        stderr=subprocess.STDOUT,
        text=True,
    )
    try:
        _wait_for_health(port)
    except Exception:
        _stop_backend(process, log_handle, port)
        raise
    _log(f"Uvicorn instance {index} ready")
    return process, log_handle


def _stop_backend(process: subprocess.Popen[str] | None, log_handle: object | None, port: int) -> None:
    if process is not None and process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)
    if log_handle is not None:
        log_handle.close()
    _wait_for_health_down(port)


def _run_godot_phase(godot: str, phase: str, port: int, user_home: Path) -> None:
    env = os.environ.copy()
    env.update(
        {
            "NPC_BACKEND_URL": f"http://127.0.0.1:{port}",
            "NPC_E2E_PHASE": phase,
            "NPC_E2E_ISOLATED_USER_HOME": "1",
            "GODOT_USER_HOME": str(user_home),
        }
    )
    log_path = ARTIFACT_ROOT / f"godot-{phase}.log"
    _command(
        [
            godot,
            "--headless",
            "--path",
            str(REPO_ROOT),
            "--script",
            "res://tests/e2e/npc_cognition_cross_process_runner.gd",
        ],
        cwd=REPO_ROOT,
        env=env,
        log_path=log_path,
        timeout=240,
    )
    _validate_godot_log(log_path)


def _validate_godot_log(path: Path) -> None:
    value = path.read_text(encoding="utf-8", errors="replace")
    forbidden = (
        "SCRIPT ERROR:",
        "Parser Error:",
        "ObjectDB instances were leaked",
        "resources still in use at exit",
        "RID allocations of type",
        "ERROR:",
    )
    findings = [marker for marker in forbidden if marker in value]
    if findings:
        raise AcceptanceFailure(
            f"unexpected Godot diagnostics in {path.name}: {', '.join(findings)}"
        )


def _create_temporary_database(base_url: str) -> tuple[str, str]:
    parsed = make_url(base_url)
    database_name = f"stillpoint_e2e_{uuid.uuid4().hex[:12]}"
    with psycopg.connect(_psycopg_url(base_url), autocommit=True) as connection:
        connection.execute(sql.SQL("CREATE DATABASE {}").format(sql.Identifier(database_name)))
    temporary = parsed.set(database=database_name)
    return temporary.render_as_string(hide_password=False), database_name


def _drop_temporary_database(base_url: str, database_name: str) -> None:
    with psycopg.connect(_psycopg_url(base_url), autocommit=True) as connection:
        connection.execute(
            "SELECT pg_terminate_backend(pid) FROM pg_stat_activity "
            "WHERE datname = %s AND pid <> pg_backend_pid()",
            (database_name,),
        )
        connection.execute(sql.SQL("DROP DATABASE IF EXISTS {}").format(sql.Identifier(database_name)))


def _psycopg_url(value: str | URL) -> str:
    parsed = make_url(str(value)).set(drivername="postgresql")
    return parsed.render_as_string(hide_password=False)


def _verify_seed_database(database_url: str) -> None:
    with psycopg.connect(_psycopg_url(database_url)) as connection:
        with connection.cursor() as cursor:
            checks = {
                "conversation sessions": "SELECT COUNT(*) FROM conversation_sessions",
                "conversation turns": "SELECT COUNT(*) FROM conversation_turns",
                "memories": "SELECT COUNT(*) FROM npc_memories",
                "usage records": "SELECT COUNT(*) FROM usage_records",
            }
            minimums = {
                "conversation sessions": 3,
                "conversation turns": 6,
                "memories": 3,
                "usage records": 3,
            }
            for label, query in checks.items():
                cursor.execute(query)
                value = int(cursor.fetchone()[0])
                if value < minimums[label]:
                    raise AcceptanceFailure(f"seed database missing {label}: {value}")
            cursor.execute(
                "SELECT COUNT(*) FROM npc_memories WHERE npc_persistent_id=%s "
                "AND lower(content) LIKE '%%blue%%'",
                ("base:town/npc/mira",),
            )
            if int(cursor.fetchone()[0]) != 1:
                raise AcceptanceFailure("Mira blue memory was not persisted")
            cursor.execute(
                "SELECT COUNT(*) FROM npc_memories WHERE npc_persistent_id=%s "
                "AND lower(content) LIKE '%%silver%%'",
                ("base:dungeon/npc/bandit_0001",),
            )
            if int(cursor.fetchone()[0]) != 1:
                raise AcceptanceFailure("bandit_0001 moon memory was not persisted")
            cursor.execute(
                "SELECT COUNT(*) FROM npc_memories WHERE npc_persistent_id=%s "
                "AND lower(content) LIKE '%%silver%%'",
                ("base:dungeon/npc/bandit_0002",),
            )
            if int(cursor.fetchone()[0]) != 0:
                raise AcceptanceFailure("bandit instance isolation failed in PostgreSQL")
            cursor.execute(
                "SELECT COUNT(*) FROM npc_memories WHERE npc_persistent_id=%s "
                "AND source_type='gameplay_event' AND lower(content) LIKE '%%npc_attacked%%'",
                ("base:town/npc/mira",),
            )
            if int(cursor.fetchone()[0]) < 1:
                raise AcceptanceFailure("Mira attack event memory was not persisted")
            cursor.execute("SELECT DISTINCT vector_dims(embedding) FROM npc_memories")
            dimensions = {int(row[0]) for row in cursor.fetchall()}
            if dimensions != {1536}:
                raise AcceptanceFailure(f"unexpected embedding dimensions: {dimensions}")


def _verify_final_database(database_url: str) -> None:
    with psycopg.connect(_psycopg_url(database_url)) as connection:
        with connection.cursor() as cursor:
            cursor.execute(
                "SELECT COUNT(*), COUNT(DISTINCT (player_profile_id, world_save_id, "
                "npc_persistent_id, outbox_kind, entry_id)) FROM outbox_receipts"
            )
            total, unique = (int(value) for value in cursor.fetchone())
            if total < 3 or total != unique:
                raise AcceptanceFailure(
                    f"outbox idempotency receipts invalid: total={total} unique={unique}"
                )
            cursor.execute(
                "SELECT COUNT(*) FROM npc_profile_deployments GROUP BY player_profile_id, "
                "world_save_id, npc_persistent_id HAVING COUNT(*) > 1"
            )
            if cursor.fetchall():
                raise AcceptanceFailure("more than one trusted profile is deployed per NPC instance")
            cursor.execute(
                "SELECT COUNT(*) FROM outbox_receipts WHERE outbox_kind='event'"
            )
            if int(cursor.fetchone()[0]) < 2:
                raise AcceptanceFailure("offline gameplay event did not receive a durable Ack")


def _scan_logs(signing_key: str) -> None:
    for path in ARTIFACT_ROOT.glob("*.log"):
        value = path.read_text(encoding="utf-8", errors="replace")
        for marker in (*FORBIDDEN_LOG_MARKERS, signing_key):
            if marker and marker in value:
                raise AcceptanceFailure(f"secret-bearing marker found in {path.name}")


def _tail_failure_logs() -> None:
    for path in sorted(ARTIFACT_ROOT.glob("*.log")):
        lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
        print(f"\n--- {path.name} (last 40 lines) ---", file=sys.stderr)
        print("\n".join(lines[-40:]), file=sys.stderr)


def _docker_postgres_running() -> bool:
    result = subprocess.run(
        ["docker", "compose", "ps", "--status", "running", "--services"],
        cwd=BACKEND_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    return result.returncode == 0 and "postgres" in result.stdout.splitlines()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.getenv("GODOT_BIN", "godot"))
    parser.add_argument(
        "--database-url",
        default=os.getenv(
            "NPC_E2E_DATABASE_URL",
            "postgresql+psycopg://stillpoint:stillpoint@127.0.0.1:55432/stillpoint",
        ),
    )
    parser.add_argument("--backend-port", type=int, default=18443)
    parser.add_argument("--postgres-already-running", action="store_true")
    args = parser.parse_args()

    godot = shutil.which(args.godot) or (args.godot if Path(args.godot).is_file() else "")
    if not godot:
        print(f"Godot executable not found: {args.godot}", file=sys.stderr)
        return 2

    ARTIFACT_ROOT.mkdir(parents=True, exist_ok=True)
    for path in ARTIFACT_ROOT.glob("*.log"):
        path.unlink()
    user_home = ARTIFACT_ROOT / "godot-user-home"
    if user_home.exists():
        shutil.rmtree(user_home)
    user_home.mkdir(parents=True)

    compose_started = False
    database_name = ""
    temporary_url = ""
    backend: subprocess.Popen[str] | None = None
    backend_log: object | None = None
    signing_key = secrets.token_urlsafe(48)
    try:
        if not args.postgres_already_running:
            already_running = _docker_postgres_running()
            _command(["docker", "compose", "up", "-d", "postgres"], cwd=BACKEND_ROOT)
            compose_started = not already_running
        _wait_for_database(args.database_url)
        temporary_url, database_name = _create_temporary_database(args.database_url)
        _log("temporary PostgreSQL database created")

        migration_env = os.environ.copy()
        migration_env["DATABASE_URL"] = temporary_url
        import_log = ARTIFACT_ROOT / "godot-import.log"
        _command(
            [sys.executable, "-m", "alembic", "-c", "alembic.ini", "upgrade", "head"],
            cwd=BACKEND_ROOT,
            env=migration_env,
            log_path=ARTIFACT_ROOT / "alembic.log",
        )
        import_env = os.environ.copy()
        import_env["GODOT_USER_HOME"] = str(user_home)
        _command(
            [godot, "--headless", "--path", str(REPO_ROOT), "--editor", "--quit"],
            cwd=REPO_ROOT,
            env=import_env,
            log_path=import_log,
            timeout=180,
        )
        _validate_godot_log(import_log)

        backend, backend_log = _start_backend(temporary_url, args.backend_port, signing_key, 1)
        _run_godot_phase(godot, "seed", args.backend_port, user_home)
        _verify_seed_database(temporary_url)
        _stop_backend(backend, backend_log, args.backend_port)
        backend = None
        backend_log = None

        backend, backend_log = _start_backend(temporary_url, args.backend_port, signing_key, 2)
        _run_godot_phase(godot, "recall", args.backend_port, user_home)
        _stop_backend(backend, backend_log, args.backend_port)
        backend = None
        backend_log = None

        _run_godot_phase(godot, "offline", args.backend_port, user_home)

        backend, backend_log = _start_backend(temporary_url, args.backend_port, signing_key, 3)
        _run_godot_phase(godot, "flush", args.backend_port, user_home)
        _verify_final_database(temporary_url)
        _scan_logs(signing_key)
        _stop_backend(backend, backend_log, args.backend_port)
        backend = None
        backend_log = None
        _log("all cross-process scenarios passed")
        return 0
    except (AcceptanceFailure, OSError, psycopg.Error, subprocess.TimeoutExpired) as error:
        print(f"Cross-process E2E failed: {error}", file=sys.stderr)
        _tail_failure_logs()
        return 1
    finally:
        with suppress(Exception):
            _stop_backend(backend, backend_log, args.backend_port)
        if database_name:
            with suppress(Exception):
                _drop_temporary_database(args.database_url, database_name)
                _log("temporary PostgreSQL database removed")
        if compose_started:
            with suppress(Exception):
                _command(["docker", "compose", "stop", "postgres"], cwd=BACKEND_ROOT)


if __name__ == "__main__":
    raise SystemExit(main())
