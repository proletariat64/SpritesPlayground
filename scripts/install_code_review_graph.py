#!/usr/bin/env python3
"""Ensure the pinned code-review-graph development tool is installed."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
from pathlib import Path
from typing import Any

PROJECT_ROOT = Path(__file__).resolve().parent.parent
LOCK_PATH = PROJECT_ROOT / "dependencies" / "code_review_graph.lock.json"


def _load_lock(path: Path) -> dict[str, Any]:
    try:
        lock = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise SystemExit(f"Cannot read code-review-graph lock at {path}: {error}") from error
    if not isinstance(lock, dict):
        raise SystemExit(f"code-review-graph lock at {path} must contain a JSON object")
    for key in ("package", "version", "command"):
        if not isinstance(lock.get(key), str) or not lock[key]:
            raise SystemExit(f"code-review-graph lock at {path} requires a non-empty {key!r}")
    return lock


def _run(command: list[str]) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(command, check=False, capture_output=True, text=True)
    except OSError as error:
        return subprocess.CompletedProcess(command, 1, "", str(error))


def _health(lock: dict[str, Any]) -> tuple[bool, str]:
    executable = shutil.which(str(lock["command"]))
    if executable is None:
        return False, f"code-review-graph {lock['version']} required; command not installed"
    result = _run([executable, "--version"])
    output = (result.stdout + result.stderr).strip()
    actual = output.split()[-1] if result.returncode == 0 and output else "unknown"
    if actual != lock["version"]:
        return False, f"code-review-graph {lock['version']} required; found {actual} at {executable}"
    return True, f"code-review-graph {actual} ready at {executable}"


def _install(lock: dict[str, Any]) -> None:
    uv = shutil.which("uv")
    if uv is None:
        raise SystemExit(
            "Required tool 'uv' was not found; install it from "
            "https://docs.astral.sh/uv/getting-started/installation/"
        )
    package_spec = f"{lock['package']}=={lock['version']}"
    result = _run([uv, "tool", "install", "--force", package_spec])
    if result.returncode != 0:
        output = (result.stdout + result.stderr).strip()
        if output:
            print(output)
        raise SystemExit(f"uv tool install failed for {package_spec}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lock", type=Path, default=LOCK_PATH, help="Pinned tool lock file")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true", help="Verify without installing the tool")
    mode.add_argument("--repair", action="store_true", help="Reinstall the pinned tool even when healthy")
    args = parser.parse_args()

    lock = _load_lock(args.lock.resolve())
    healthy, message = _health(lock)
    if args.check:
        print(message)
        return 0 if healthy else 1
    if healthy and not args.repair:
        print(f"{message}; already healthy; skipping installation")
        return 0

    print(f"{message}; installing pinned tool", flush=True)
    _install(lock)
    healthy, message = _health(lock)
    if not healthy:
        print(message)
        return 1
    print(f"Installed {lock['package']}=={lock['version']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
