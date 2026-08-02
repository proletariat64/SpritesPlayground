#!/usr/bin/env python3
"""Ensure or verify the pinned SpritesPlayground development environment."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
GODOT_LOCK = PROJECT_ROOT / "dependencies" / "godot.lock.json"
INSTALL_LIMBOAI = PROJECT_ROOT / "scripts" / "install_limboai.py"
INSTALL_GODOT_AI = PROJECT_ROOT / "scripts" / "install_godot_ai.py"
INSTALL_CODE_REVIEW_GRAPH = PROJECT_ROOT / "scripts" / "install_code_review_graph.py"
INSTALL_PI_PACKAGES = PROJECT_ROOT / "scripts" / "install_pi_packages.py"


def _load_json(path: Path, label: str) -> dict[str, str]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise RuntimeError(f"Cannot read {label} at {path}: {error}") from error


def _require_tool(name: str, install_hint: str) -> str:
    executable = shutil.which(name)
    if executable is None:
        raise RuntimeError(f"Required tool '{name}' was not found. {install_hint}")
    return executable


def _run(command: list[str]) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(command, check=False, capture_output=True, text=True)
    except OSError as error:
        return subprocess.CompletedProcess(command, 1, "", str(error))


def _print_result(label: str, result: subprocess.CompletedProcess[str]) -> None:
    output = (result.stdout + result.stderr).strip()
    if output:
        print(f"[{label}] {output}")


def _check_godot() -> str:
    lock = _load_json(GODOT_LOCK, "Godot lock")
    executable = _require_tool(
        lock.get("command", "godot"),
        f"Install the pinned Godot {lock['version']} build and put it on PATH.",
    )
    result = _run([executable, "--version"])
    actual = result.stdout.strip().splitlines()[0] if result.stdout.strip() else "unknown"
    if result.returncode != 0 or actual != lock["version"]:
        raise RuntimeError(f"Godot {lock['version']} is required; found {actual} at {executable}")
    print(f"Godot {actual} ready at {executable}")
    return executable


def _dependency_commands(
    project_root: Path,
    check: bool,
    repair: bool,
    skip_code_review_graph: bool,
    skip_pi: bool,
    pi_manifest: Path | None,
    limboai_archive: Path | None,
    godot_ai_archive: Path | None,
) -> list[tuple[str, list[str]]]:
    limbo = [sys.executable, str(INSTALL_LIMBOAI), "--project-root", str(project_root)]
    godot_ai = [sys.executable, str(INSTALL_GODOT_AI), "--project-root", str(project_root)]
    commands = [("LimboAI runtime dependency", limbo), ("Godot AI development tool", godot_ai)]
    if not skip_code_review_graph:
        commands.append(
            (
                "code-review-graph development tool",
                [sys.executable, str(INSTALL_CODE_REVIEW_GRAPH)],
            )
        )
    if not skip_pi:
        pi_packages = [
            sys.executable,
            str(INSTALL_PI_PACKAGES),
            "--project-root",
            str(project_root),
        ]
        if pi_manifest is not None:
            pi_packages.extend(["--manifest", str(pi_manifest)])
        commands.append(("Pi development packages", pi_packages))
    if check:
        for _, command in commands:
            command.append("--check")
    else:
        if repair:
            for _, command in commands:
                command.append("--repair")
        if limboai_archive is not None:
            limbo.extend(["--archive", str(limboai_archive)])
        if godot_ai_archive is not None:
            godot_ai.extend(["--archive", str(godot_ai_archive)])
    return commands


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=Path, default=PROJECT_ROOT, help="Checkout to prepare")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true", help="Verify without installing or importing")
    mode.add_argument("--repair", action="store_true", help="Reinstall pinned dependencies even when healthy")
    parser.add_argument("--skip-import", action="store_true", help="Ensure dependencies without running Godot import")
    parser.add_argument(
        "--skip-code-review-graph",
        action="store_true",
        help="Skip code-review-graph verification",
    )
    parser.add_argument("--skip-pi", action="store_true", help="Skip external Pi package verification")
    parser.add_argument("--pi-manifest", type=Path, help="Use an alternate pinned Pi package manifest")
    parser.add_argument("--limboai-archive", type=Path, help="Use the pinned LimboAI release archive")
    parser.add_argument("--godot-ai-archive", type=Path, help="Use the pinned Godot AI release archive")
    args = parser.parse_args()

    project_root = args.project_root.resolve()
    failures: list[str] = []
    try:
        godot = _check_godot()
    except RuntimeError as error:
        failures.append(str(error))
        godot = ""
    try:
        uv = _require_tool(
            "uv",
            "Install uv from https://docs.astral.sh/uv/getting-started/installation/.",
        )
        print(f"uv ready at {uv}")
    except RuntimeError as error:
        failures.append(str(error))

    for label, command in _dependency_commands(
        project_root,
        args.check,
        args.repair,
        args.skip_code_review_graph,
        args.skip_pi,
        args.pi_manifest,
        args.limboai_archive,
        args.godot_ai_archive,
    ):
        print(f"Ensuring {label}...", flush=True)
        if args.check:
            result = _run(command)
            _print_result(label, result)
        else:
            try:
                result = subprocess.run(command, check=False)
            except OSError as error:
                result = subprocess.CompletedProcess(command, 1, "", str(error))
                _print_result(label, result)
        if result.returncode != 0:
            failures.append(f"{label} failed")

    if failures:
        print("Development bootstrap failed:", file=sys.stderr)
        for failure in failures:
            print(f"- {failure}", file=sys.stderr)
        return 1

    if not args.check and not args.skip_import:
        try:
            result = subprocess.run(
                [godot, "--headless", "--editor", "--path", str(project_root), "--quit"],
                check=False,
            )
        except OSError as error:
            print(f"Godot editor import failed: {error}", file=sys.stderr)
            return 1
        if result.returncode != 0:
            print("Godot editor import failed", file=sys.stderr)
            return result.returncode or 1

    print(
        "SpritesPlayground development bootstrap ready: "
        "pinned Godot + LimboAI runtime + Godot AI development/UAT + "
        "code-review-graph + Pi packages"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
