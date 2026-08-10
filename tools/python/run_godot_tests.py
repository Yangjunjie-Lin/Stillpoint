"""Run Godot tests and reject unexpected runtime diagnostics."""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path


ANSI_RE = re.compile(r"\x1b\[[0-?]*[ -/]*[@-~]")
SUMMARY_RE = re.compile(r"Stillpoint tests:\s*(\d+) passed,\s*(\d+) failed")
OBJECTDB_RE = re.compile(r"(\d+) ObjectDB instances were leaked at exit")
RESOURCE_RE = re.compile(r"(\d+) resources still in use at exit")
FATAL_PATTERNS = (
    "SCRIPT ERROR:",
    "Parser Error:",
    "Invalid access",
    "Invalid call",
    "Invalid get index",
    "Cannot assign",
    "Attempt to call function",
    "Node not found",
)


def _load_allowlist(path: Path) -> list[re.Pattern[str]]:
    patterns: list[re.Pattern[str]] = []
    for line_number, raw_line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        try:
            patterns.append(re.compile(line))
        except re.error as exc:
            raise ValueError(f"invalid expected-error regex at {path}:{line_number}: {exc}") from exc
    return patterns


def _is_expected_error(line: str, allowlist: list[re.Pattern[str]]) -> bool:
    return any(pattern.search(line) for pattern in allowlist)


def _format_context(lines: list[str], indexes: list[int]) -> str:
    selected: list[str] = []
    seen: set[int] = set()
    for index in indexes:
        for candidate in range(max(0, index - 2), min(len(lines), index + 3)):
            if candidate in seen:
                continue
            seen.add(candidate)
            selected.append(f"{candidate + 1}: {lines[candidate]}")
    return "\n".join(selected)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot", help="Godot executable")
    parser.add_argument("--expected-tests", type=int, default=285)
    parser.add_argument("--max-objectdb-leaks", type=int, default=0)
    parser.add_argument("--max-resource-leaks", type=int, default=0)
    parser.add_argument("--log", default="artifacts/godot-test.log")
    args = parser.parse_args()

    repo_root = Path(__file__).resolve().parents[2]
    allowlist_path = repo_root / "tests" / "expected_error_patterns.txt"
    log_path = repo_root / args.log
    log_path.parent.mkdir(parents=True, exist_ok=True)
    allowlist = _load_allowlist(allowlist_path)
    command = [
        args.godot,
        "--headless",
        "--path",
        str(repo_root),
        "--script",
        "res://tests/test_runner.gd",
    ]

    lines: list[str] = []
    with log_path.open("w", encoding="utf-8", newline="\n") as log_file:
        try:
            process = subprocess.Popen(
                command,
                cwd=repo_root,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                encoding="utf-8",
                errors="replace",
                bufsize=1,
            )
        except OSError as exc:
            print(f"Unable to start Godot: {exc}", file=sys.stderr)
            return 2
        assert process.stdout is not None
        for raw_line in process.stdout:
            line = ANSI_RE.sub("", raw_line.rstrip("\r\n"))
            lines.append(line)
            print(line, flush=True)
            log_file.write(line + "\n")
        return_code = process.wait()

    fatal_indexes = [
        index for index, line in enumerate(lines) if any(pattern in line for pattern in FATAL_PATTERNS)
    ]
    unexpected_error_indexes: list[int] = []
    objectdb_leaks = 0
    resource_leaks = 0
    for index, line in enumerate(lines):
        objectdb_match = OBJECTDB_RE.search(line)
        if objectdb_match:
            objectdb_leaks = int(objectdb_match.group(1))
        resource_match = RESOURCE_RE.search(line)
        if resource_match:
            resource_leaks = int(resource_match.group(1))
        if line.startswith("ERROR:") and "resources still in use at exit" not in line:
            if not _is_expected_error(line, allowlist):
                unexpected_error_indexes.append(index)

    summaries = [SUMMARY_RE.search(line) for line in lines]
    summary = next((match for match in reversed(summaries) if match), None)
    failures: list[str] = []
    if return_code != 0:
        failures.append(f"Godot exited with code {return_code}")
    if summary is None:
        failures.append("missing test Summary")
        passed = failed = 0
    else:
        passed, failed = (int(value) for value in summary.groups())
        if passed < args.expected_tests:
            failures.append(f"passed tests {passed} is below expected {args.expected_tests}")
        if failed != 0:
            failures.append(f"failed tests reported by Godot: {failed}")
    if fatal_indexes:
        failures.append(f"unexpected fatal runtime diagnostics: {len(fatal_indexes)}")
    if unexpected_error_indexes:
        failures.append(f"unexpected ERROR diagnostics: {len(unexpected_error_indexes)}")
    if objectdb_leaks > args.max_objectdb_leaks:
        failures.append(f"ObjectDB leaks {objectdb_leaks} exceed {args.max_objectdb_leaks}")
    if resource_leaks > args.max_resource_leaks:
        failures.append(f"Resource leaks {resource_leaks} exceed {args.max_resource_leaks}")

    print(f"Godot tests: {passed} passed, {failed} failed")
    print(f"Unexpected SCRIPT ERROR: {sum('SCRIPT ERROR:' in lines[i] for i in fatal_indexes)}")
    print(f"Unexpected ERROR: {len(unexpected_error_indexes)}")
    print(f"ObjectDB leaks: {objectdb_leaks}")
    print(f"Resource leaks: {resource_leaks}")
    if failures:
        print("\nGodot test log validation failed:")
        for failure in failures:
            print(f"- {failure}")
        indexes = sorted(set(fatal_indexes + unexpected_error_indexes))
        if indexes:
            print("\nMatched diagnostic context:")
            print(_format_context(lines, indexes))
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
