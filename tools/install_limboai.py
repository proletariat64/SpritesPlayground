#!/usr/bin/env python3
"""Install the pinned LimboAI GDExtension into a local build environment."""

from __future__ import annotations

import argparse
import hashlib
import json
import platform
import shutil
import sys
import tempfile
import urllib.request
import zipfile
from pathlib import Path, PurePosixPath

PROJECT_ROOT = Path(__file__).resolve().parent.parent
LOCK_PATH = PROJECT_ROOT / "dependencies" / "limboai.lock.json"
COMMON_FILES = {
    "LICENSE.md",
    "LOGO_LICENSE.md",
    "README.md",
    "version.txt",
    "bin/limboai.gdextension",
    "bin/limboai.gdextension.uid",
}
PLATFORM_PREFIXES = {
    "linux-x86_64": ("bin/liblimboai.linux.editor.x86_64.so", "bin/liblimboai.linux.template_release.x86_64.so"),
    "linux-arm64": ("bin/liblimboai.linux.editor.arm64.so", "bin/liblimboai.linux.template_release.arm64.so"),
    "windows-x86_64": ("bin/liblimboai.windows.editor.x86_64.dll", "bin/liblimboai.windows.template_release.x86_64.dll"),
    "macos-universal": ("bin/liblimboai.macos.editor.framework/", "bin/liblimboai.macos.template_release.framework/"),
    "android": ("bin/liblimboai.android.",),
    "ios": ("bin/liblimboai.ios.",),
    "web": ("bin/liblimboai.web.",),
}


def _detect_platform() -> str:
    machine = platform.machine().lower()
    if sys.platform.startswith("linux"):
        return "linux-arm64" if machine in {"aarch64", "arm64"} else "linux-x86_64"
    if sys.platform == "win32":
        return "windows-x86_64"
    if sys.platform == "darwin":
        return "macos-universal"
    raise SystemExit(f"Unsupported host platform: {sys.platform}/{machine}; pass --platform explicitly")


def _load_lock() -> dict[str, str]:
    return json.loads(LOCK_PATH.read_text(encoding="utf-8"))


def _download(url: str, destination: Path) -> None:
    print(f"Downloading {url}")
    with urllib.request.urlopen(url) as response, destination.open("wb") as output:
        shutil.copyfileobj(response, output)


def _verify_archive(archive: Path, expected_sha256: str) -> None:
    digest = hashlib.sha256()
    with archive.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    actual = digest.hexdigest()
    if actual != expected_sha256:
        raise SystemExit(f"LimboAI archive checksum mismatch: expected {expected_sha256}, got {actual}")


def _wanted(relative: str, target_platform: str, all_platforms: bool) -> bool:
    if relative in COMMON_FILES or relative.startswith("icons/"):
        return True
    if all_platforms and relative.startswith("bin/liblimboai."):
        return True
    return any(relative == prefix or relative.startswith(prefix) for prefix in PLATFORM_PREFIXES[target_platform])


def _extract(archive: Path, destination: Path, target_platform: str, all_platforms: bool) -> int:
    prefix = "addons/limboai/"
    extracted = 0
    with zipfile.ZipFile(archive) as package:
        for member in package.infolist():
            if member.is_dir() or not member.filename.startswith(prefix):
                continue
            relative = member.filename[len(prefix) :]
            safe_parts = PurePosixPath(relative).parts
            if not relative or ".." in safe_parts or not _wanted(relative, target_platform, all_platforms):
                continue
            output = destination.joinpath(*safe_parts)
            output.parent.mkdir(parents=True, exist_ok=True)
            with package.open(member) as source, output.open("wb") as target:
                shutil.copyfileobj(source, target)
            extracted += 1
    return extracted


def _required_binaries(target_platform: str) -> tuple[str, ...]:
    return tuple(prefix for prefix in PLATFORM_PREFIXES[target_platform] if not prefix.endswith(("/", ".")))


def _check(install_path: Path, lock: dict[str, str], target_platform: str, all_platforms: bool) -> None:
    version_file = install_path / "version.txt"
    expected_version = f"v{lock['version']}"
    actual_version = version_file.read_text(encoding="utf-8").strip() if version_file.exists() else "missing"
    if actual_version != expected_version:
        raise SystemExit(f"LimboAI {expected_version} is required at {install_path}; found {actual_version}")
    if not all_platforms:
        missing = [name for name in _required_binaries(target_platform) if not (install_path / name).is_file()]
        if missing:
            raise SystemExit(f"LimboAI installation is incomplete for {target_platform}: {', '.join(missing)}")
    print(f"LimboAI {expected_version} ready for {target_platform} at {install_path}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", choices=sorted(PLATFORM_PREFIXES), default=None)
    parser.add_argument("--all-platforms", action="store_true", help="Install every binary shipped in the pinned archive")
    parser.add_argument("--archive", type=Path, help="Use a previously downloaded release archive")
    parser.add_argument("--project-root", type=Path, default=PROJECT_ROOT, help="Installation root (defaults to this checkout)")
    parser.add_argument("--check", action="store_true", help="Verify the required local installation without downloading")
    args = parser.parse_args()

    lock = _load_lock()
    target_platform = args.platform or _detect_platform()
    install_path = args.project_root.resolve() / lock["install_path"]
    if args.check:
        _check(install_path, lock, target_platform, args.all_platforms)
        return 0

    with tempfile.TemporaryDirectory(prefix="limboai-install-") as temp_dir_name:
        temp_dir = Path(temp_dir_name)
        archive = args.archive.resolve() if args.archive else temp_dir / lock["asset_name"]
        if not args.archive:
            _download(lock["download_url"], archive)
        _verify_archive(archive, lock["sha256"])
        extracted_root = temp_dir / "limboai"
        extracted = _extract(archive, extracted_root, target_platform, args.all_platforms)
        if extracted == 0:
            raise SystemExit("Pinned LimboAI archive did not contain the expected add-on files")
        install_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.rmtree(install_path, ignore_errors=True)
        shutil.copytree(extracted_root, install_path)

    _check(install_path, lock, target_platform, args.all_platforms)
    print(f"Installed {extracted} files; addons/limboai remains build-local and gitignored")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
