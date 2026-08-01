#!/usr/bin/env python3
"""Ensure the pinned external Pi packages used by this project are installed."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Any

PROJECT_ROOT = Path(__file__).resolve().parent.parent
MANIFEST_PATH = PROJECT_ROOT / "dependencies" / "pi_packages.lock.json"


def _load_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise SystemExit(f"Cannot read {label} at {path}: {error}") from error
    if not isinstance(value, dict):
        raise SystemExit(f"{label} at {path} must contain a JSON object")
    return value


def _npm_package_path(root: Path, package_name: str) -> Path:
    return root.joinpath(*package_name.split("/"), "package.json")


def _npm_health(package: dict[str, Any], project_root: Path) -> tuple[bool, str]:
    roots = (
        project_root / ".pi" / "npm" / "node_modules",
        Path.home() / ".pi" / "agent" / "npm" / "node_modules",
    )
    found_versions: list[str] = []
    for root in roots:
        package_path = _npm_package_path(root, str(package["name"]))
        if not package_path.is_file():
            continue
        try:
            metadata = json.loads(package_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            found_versions.append(f"unreadable at {package_path}")
            continue
        actual = str(metadata.get("version", "missing"))
        if actual == package["version"]:
            return True, f"{package['source']} ready at {package_path.parent}"
        found_versions.append(f"{actual} at {package_path.parent}")
    found = ", ".join(found_versions) if found_versions else "not installed"
    return False, f"{package['source']} required; found {found}"


def _git_root(path: Path) -> Path | None:
    candidate = path if path.is_dir() else path.parent
    for parent in (candidate, *candidate.parents):
        if (parent / ".git").exists():
            return parent
    return None


def _settings_git_roots() -> set[Path]:
    settings_path = Path.home() / ".pi" / "agent" / "settings.json"
    if not settings_path.is_file():
        return set()
    try:
        settings = json.loads(settings_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return set()
    roots: set[Path] = set()
    for extension in settings.get("extensions", []):
        if not isinstance(extension, str):
            continue
        root = _git_root(Path(extension).expanduser())
        if root is not None:
            roots.add(root)
    return roots


def _normalized_remote(remote: str) -> str:
    value = remote.strip().removeprefix("git:").removesuffix(".git")
    if value.startswith("git@github.com:"):
        value = "https://github.com/" + value.removeprefix("git@github.com:")
    if value.startswith("github.com/"):
        value = "https://" + value
    return value


def _git_value(root: Path, *args: str) -> str | None:
    try:
        result = subprocess.run(
            ["git", "-C", str(root), *args],
            check=False,
            capture_output=True,
            text=True,
        )
    except OSError:
        return None
    return result.stdout.strip() if result.returncode == 0 else None


def _git_health(package: dict[str, Any], project_root: Path) -> tuple[bool, str]:
    relative = Path(str(package["repository_path"]))
    candidates = {
        project_root / ".pi" / "git" / relative,
        Path.home() / ".pi" / "agent" / "git" / relative,
        *_settings_git_roots(),
    }
    expected_remote = _normalized_remote(str(package["remote_url"]))
    failures: list[str] = []
    for root in sorted(candidates):
        if not root.is_dir():
            continue
        commit = _git_value(root, "rev-parse", "HEAD")
        remote = _git_value(root, "remote", "get-url", "origin")
        if commit != package["commit"] or remote is None or _normalized_remote(remote) != expected_remote:
            failures.append(f"{commit or 'unreadable'} at {root}")
            continue
        filters = package.get("resource_filters", {})
        resources = [resource for values in filters.values() for resource in values]
        missing = [resource for resource in resources if not (root / resource).is_file()]
        if missing:
            failures.append(f"missing {', '.join(missing)} at {root}")
            continue
        return True, f"{package['source']} ready at {root}"
    found = ", ".join(failures) if failures else "not installed"
    return False, f"{package['source']} required; found {found}"


def _health(package: dict[str, Any], project_root: Path) -> tuple[bool, str]:
    package_type = package.get("type")
    if package_type == "npm":
        return _npm_health(package, project_root)
    if package_type == "git":
        return _git_health(package, project_root)
    return False, f"Unsupported Pi package type {package_type!r} for {package.get('source', 'unknown')}"


def _source_identity(source: str) -> str:
    return source.rsplit("@", 1)[0]


def _apply_git_filters(package: dict[str, Any]) -> None:
    filters = package.get("resource_filters")
    if not isinstance(filters, dict):
        return
    settings_path = Path.home() / ".pi" / "agent" / "settings.json"
    settings_path.parent.mkdir(parents=True, exist_ok=True)
    settings = _load_json(settings_path, "Pi user settings") if settings_path.exists() else {}
    packages = settings.get("packages", [])
    if not isinstance(packages, list):
        raise SystemExit(f"Pi user settings packages at {settings_path} must be a list")
    identity = _source_identity(str(package["source"]))
    retained: list[Any] = []
    for entry in packages:
        entry_source = entry.get("source", "") if isinstance(entry, dict) else entry
        if isinstance(entry_source, str) and _source_identity(entry_source) == identity:
            continue
        retained.append(entry)
    retained.append({"source": package["source"], **filters})
    settings["packages"] = retained
    try:
        with tempfile.NamedTemporaryFile(
            "w",
            encoding="utf-8",
            dir=settings_path.parent,
            prefix="settings-",
            suffix=".json",
            delete=False,
        ) as output:
            json.dump(settings, output, indent=2)
            output.write("\n")
            temporary_path = Path(output.name)
        os.replace(temporary_path, settings_path)
    except OSError as error:
        raise SystemExit(f"Cannot update Pi package filters at {settings_path}: {error}") from error


def _install(package: dict[str, Any]) -> None:
    pi = shutil.which("pi")
    if pi is None:
        raise SystemExit("Required tool 'pi' was not found; install Pi before external packages")
    try:
        result = subprocess.run([pi, "install", str(package["source"])], check=False)
    except OSError as error:
        raise SystemExit(f"Cannot run pi install for {package['source']}: {error}") from error
    if result.returncode != 0:
        raise SystemExit(f"pi install failed for {package['source']}")
    if package.get("type") == "git":
        _apply_git_filters(package)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=MANIFEST_PATH, help="Pinned Pi package manifest")
    parser.add_argument("--project-root", type=Path, default=PROJECT_ROOT, help="Project checkout")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true", help="Verify without installing packages")
    mode.add_argument("--repair", action="store_true", help="Run pi install for every pinned package")
    args = parser.parse_args()

    manifest = _load_json(args.manifest.resolve(), "Pi package manifest")
    packages = manifest.get("packages")
    if not isinstance(packages, list):
        raise SystemExit("Pi package manifest must contain a packages list")
    project_root = args.project_root.resolve()
    failures: list[str] = []
    for package in packages:
        if not isinstance(package, dict):
            failures.append("Pi package manifest contains a non-object entry")
            continue
        healthy, message = _health(package, project_root)
        if args.check:
            print(message)
            if not healthy:
                failures.append(str(package.get("source", "unknown")))
            continue
        if healthy and not args.repair:
            print(f"{message}; already healthy; skipping installation")
            continue
        if not healthy:
            print(f"{message}; installing pinned package", flush=True)
        _install(package)
        healthy, message = _health(package, project_root)
        if not healthy:
            failures.append(message)
            continue
        print(f"Installed {package['source']}")

    if failures:
        print("Pi package verification failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1
    print("Pinned Pi packages ready")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
