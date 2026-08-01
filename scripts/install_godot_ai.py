#!/usr/bin/env python3
"""Ensure the pinned Godot AI release is installed for development and UAT."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import tempfile
import urllib.error
import urllib.request
import zipfile
from pathlib import Path, PurePosixPath

PROJECT_ROOT = Path(__file__).resolve().parent.parent
LOCK_PATH = PROJECT_ROOT / "dependencies" / "godot_ai.lock.json"
USER_AGENT = "SpritesPlayground-bootstrap"
HTTP_TIMEOUT_SECONDS = 120


def _load_lock() -> dict[str, str]:
    try:
        return json.loads(LOCK_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise SystemExit(f"Cannot read Godot AI lock at {LOCK_PATH}: {error}") from error


def _download(url: str, destination: Path) -> None:
    print(f"Downloading {url}", flush=True)
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=HTTP_TIMEOUT_SECONDS) as response, destination.open("wb") as output:
            shutil.copyfileobj(response, output)
    except (urllib.error.URLError, OSError) as error:
        raise SystemExit(f"Cannot download pinned Godot AI archive: {error}") from error


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    try:
        with path.open("rb") as source:
            for chunk in iter(lambda: source.read(1024 * 1024), b""):
                digest.update(chunk)
    except OSError as error:
        raise SystemExit(f"Cannot read Godot AI archive at {path}: {error}") from error
    return digest.hexdigest()


def _verify_archive(path: Path, expected_sha256: str) -> None:
    actual_sha256 = _sha256(path)
    if actual_sha256 != expected_sha256:
        raise SystemExit(
            f"Godot AI archive checksum mismatch: expected {expected_sha256}, got {actual_sha256}"
        )


def _extract(archive_path: Path, destination: Path) -> int:
    prefix = "addons/godot_ai/"
    extracted = 0
    try:
        with zipfile.ZipFile(archive_path) as archive:
            for member in archive.infolist():
                if member.is_dir() or not member.filename.startswith(prefix):
                    continue
                relative = member.filename[len(prefix) :]
                parts = PurePosixPath(relative).parts
                if not relative or ".." in parts:
                    continue
                output = destination.joinpath(*parts)
                output.parent.mkdir(parents=True, exist_ok=True)
                with archive.open(member) as source, output.open("wb") as target:
                    shutil.copyfileobj(source, target)
                extracted += 1
    except (OSError, zipfile.BadZipFile) as error:
        raise SystemExit(f"Cannot extract Godot AI archive at {archive_path}: {error}") from error
    return extracted


def _plugin_version(install_path: Path) -> str:
    plugin_cfg = install_path / "plugin.cfg"
    if not plugin_cfg.is_file():
        raise SystemExit(f"Godot AI installation is missing {plugin_cfg}")
    try:
        content = plugin_cfg.read_text(encoding="utf-8")
    except OSError as error:
        raise SystemExit(f"Cannot read Godot AI plugin configuration at {plugin_cfg}: {error}") from error
    match = re.search(r'^version="([^"]+)"$', content, re.MULTILINE)
    if match is None:
        raise SystemExit(f"Godot AI plugin version is missing from {plugin_cfg}")
    return match.group(1)


def _check(install_path: Path, expected_version: str) -> str:
    version = _plugin_version(install_path)
    if version != expected_version:
        raise SystemExit(f"Godot AI {expected_version} is required at {install_path}; found {version}")

    plugin_script = install_path / "plugin.gd"
    export_script = install_path / "export" / "mcp_export_plugin.gd"
    game_helper = install_path / "runtime" / "game_helper.gd"
    missing = [str(path) for path in (plugin_script, export_script, game_helper) if not path.is_file()]
    if missing:
        raise SystemExit(f"Godot AI installation is incomplete: {', '.join(missing)}")
    try:
        plugin_content = plugin_script.read_text(encoding="utf-8")
        export_content = export_script.read_text(encoding="utf-8")
    except OSError as error:
        raise SystemExit(f"Cannot inspect Godot AI export-strip contract: {error}") from error
    if "add_export_plugin(" not in plugin_content:
        raise SystemExit("Godot AI export-strip is not registered by plugin.gd")
    if "autoload/_mcp_game_helper" not in export_content:
        raise SystemExit("Godot AI export-strip does not remove the MCP game helper autoload")

    print(f"Godot AI {version} ready at {install_path}; export-strip ready")
    return version


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", type=Path, help="Use the pinned release archive already on disk")
    parser.add_argument("--project-root", type=Path, default=PROJECT_ROOT, help="Installation root")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true", help="Verify without installing or downloading")
    mode.add_argument("--repair", action="store_true", help="Reinstall even when the current installation is healthy")
    args = parser.parse_args()

    lock = _load_lock()
    expected_version = lock["version"]
    install_path = args.project_root.resolve() / lock["install_path"]
    if args.check:
        _check(install_path, expected_version)
        return 0
    if not args.repair:
        try:
            _check(install_path, expected_version)
        except (OSError, SystemExit) as error:
            print(f"Godot AI needs repair: {error}")
        else:
            print(f"Godot AI {expected_version} already healthy; skipping installation")
            return 0

    with tempfile.TemporaryDirectory(prefix="godot-ai-install-") as temp_name:
        temp = Path(temp_name)
        archive_path = args.archive.resolve() if args.archive else temp / lock["asset_name"]
        if not args.archive:
            _download(lock["download_url"], archive_path)
        _verify_archive(archive_path, lock["sha256"])

        extracted_root = temp / "godot_ai"
        extracted = _extract(archive_path, extracted_root)
        if extracted == 0:
            raise SystemExit("Pinned Godot AI archive did not contain addons/godot_ai files")
        _check(extracted_root, expected_version)
        try:
            install_path.parent.mkdir(parents=True, exist_ok=True)
            if install_path.exists():
                shutil.rmtree(install_path)
            shutil.copytree(extracted_root, install_path)
        except OSError as error:
            raise SystemExit(f"Cannot replace Godot AI installation at {install_path}: {error}") from error

    version = _check(install_path, expected_version)
    print(
        f"Installed Godot AI {version} ({extracted} files); "
        "addons/godot_ai remains development-local and gitignored"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
